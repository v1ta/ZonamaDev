--
-- api.lua - API to support EmuYoda web interface
--
-- Author: Lord Kator <lordkator@swgemu.com>
--
-- Created: Mon Jan 18 07:25:04 EST 2016
--

-- Globals we will want to reference in our module
local ngx = ngx or require "ngx"
local cjson = require "cjson"
local io = require "io"
local mysql = require "resty.mysql"
local resty_sha1 = require "resty.sha1"
local resty_string = require "resty.string"
local websocket_console = require "websocket_console"
local procps = require "procps"
local os = os
local string = string
local table = table
local pairs = pairs
local require = require
local setmetatable = setmetatable
local assert = assert
local pcall = pcall
local loadfile = loadfile
local tonumber = tonumber
local setfenv = setfenv
local package = package
local session_dict = ngx.shared.session_dict
local status_dict = ngx.shared.status_dict

local api_version = "0.0.1"

module(...)

local yoda_config_path = os.getenv("HOME") .. '/server/emuyoda/yoda-config.lua'

-- local mt = { __index = _M }

------------------------------------------------------------------------------
-- Generic API helper functions
------------------------------------------------------------------------------
function init_response()
    return { response = { status = "ERROR", dbg_info = { instance = ngx.var.hostname, version = api_version, method = ngx.req.get_method() } } }
end

function return_response(r, status)
    r.response.status = status or "OK"
    ngx.say(cjson.encode(r) .. "\n")
    ngx.exit(ngx.HTTP_OK)
end

function return_error(r, error, error_code, error_description, error_id, method, service)
    r.response.error = error
    r.response.error_code = error_code
    r.response.error_description = error_description
    r.response.error_id = error_id
    r.response.method = method
    r.response.service = service
    return_response(r, "ERROR")
end

function api_lock(...)
    local args = { ... }
    local name = table.remove(args, 1)
    local code = table.remove(args, 1)
    local lock = "api.lock." .. name
    local ok, err = status_dict:add(lock, 1, 60)

    while not ok do
	ngx.sleep(0.1)
	ok, err = status_dict:add(lock, 1, 60)
    end

    local status, result = pcall(code, unpack(args))

    status_dict:delete(lock)

    return result, status
end

function SHA1Hash(password)
    local sha1 = resty_sha1:new()

    sha1:update(password)

    return resty_string.to_hex(sha1:final())
end

------------------------------------------------------------------------------
-- Config functions
------------------------------------------------------------------------------
local function load_config()
    local f, err = io.open(yoda_config_path)

    if f == nil then
	ngx.log(ngx.ERR, 'load_config failed: yoda_config_path=[' .. yoda_config_path .. '] err=' .. err)
    end

    local yoda_cfg = setmetatable({}, {__index=_G})
    assert(pcall(setfenv(assert(loadfile(yoda_config_path)), yoda_cfg)))
    setmetatable(yoda_cfg, nil)

    yoda_cfg['__FILE__'] = yoda_config_path

    local emu_config_path = yoda_cfg['emuConfigPath']

    if emu_config_path == nil then
	ngx.log(ngx.ERR, 'load_config failed, could not find yoda-cfg.emuConfifPath!')
	return { }
    end

    f, err = io.open(emu_config_path, "r")

    if f == nil then
	ngx.log(ngx.ERR, 'load_config failed: emu_config_path=[' .. emu_config_path .. '] err=' .. err)
	return { }
    end

    f:close()

    local emu_cfg = setmetatable({}, {__index=_G})
    assert(pcall(setfenv(assert(loadfile(emu_config_path)), emu_cfg)))
    setmetatable(emu_cfg, nil)

    emu_cfg['__FILE__'] = emu_config_path

    local cfg = { ['emu'] = emu_cfg, ['yoda'] = yoda_cfg }

    -- ngx.log(ngx.ERR, 'load_config = ' .. cjson.encode(cfg))

    return cfg
end

local function save_config(conf)
    --[[
    os.remove(conf_filename .. '-')
    os.rename(conf_filename, conf_filename .. '-')

    local f = assert(io.open(conf_filename, "w"))

    local c = cjson.encode(conf)

    ngx.log(ngx.ERR, 'save_config = ' .. c)

    f:write(c .. "\n")

    f:close()
    ]]

    return conf
end

------------------------------------------------------------------------------
-- Authorization related functions
------------------------------------------------------------------------------
function get_auth_user()
    local cfg = load_config()

    local token = ngx.var.cookie_ZDAPI_SESSID or ngx.req.get_headers()['authorization']

    -- ngx.log(ngx.ERR, 'get_auth_user: token =[' .. token .. ']')

    -- Localhost or server_ip w/o token logs in as yoda
    -- TODO KATOR remove that hardcoded 10.0.2.2
    if token == nil and (ngx.var.remote_addr == '127.0.0.1' or ngx.var.remote_addr == '10.0.2.2') then
	token = cfg.yoda.yodaSecret
    end

    if token == nil then
	return nil, token
    end

    -- yodaSecret 
    if token == cfg.yoda.yodaSecret then
	ngx.log(ngx.ERR, 'get_auth_user: found Yoda!')
	return {
	    account_id = -1,
	    username = 'yoda',
	    password = 'unknowable',
	    station_id = -1,
	    created = '',
	    admin_level = 16,
	    salt = ''
	}, token
    end

    local account_id = session_dict:get(token)

    if account_id then
	local resp, err, errno, sqlstate = db_query("SELECT * FROM `accounts` WHERE `account_id` = " .. account_id)

	if resp then
	    return resp[1], token
	else
	    ngx.log(ngx.ERR, 'Failed to find user for account_id=[' .. account_id .. ']: ' .. errno .. ': ' .. err .. ' (' .. sqlstate .. ')')
	    session_dict:delete(token)
	end
    end

    return nil, token
end

function auth_user(username, password)
    local user = users[username]

    if user == nil then
	return false
    end

    if user.password == password then
	return true
    end

    return false
end

function new_session_token(username)
    return ngx.encode_base64(ngx.hmac_sha1(tostring(math.random()) .. "random" .. tostring(os.time()), "apikey" .. username))
end

-- Implement /auth service
function service_auth()
    local r = init_response()

    -- GET - Verify token is valid
    if ngx.req.get_method() == "GET" then
	local user, token = get_auth_user()

	if token == nil then
	    return_error(r, "missing auth token", "MISSING_AUTH", "missing auth token", "SYSTEM", ngx.req.get_method(), "auth")
	elseif user == nil then
	    return_error(r, "auth token invalid", "NOAUTH", "Not authorized", "SYSTEM", ngx.req.get_method(), "auth")
	else
	    r.response.token = token
	    return_response(r, 'OK')
	end
    end

    -- Only support POST to auth
    if ngx.req.get_method() ~= "POST" then
	return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Post is not accepted for the auth service", "SYSTEM", ngx.req.get_method(), "auth")
    end

    -- Make sure body is read in
    ngx.req.read_body()

    -- Get post_data
    local post_data = ngx.req.get_body_data()

    if post_data == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, missing body", "SYSTEM", ngx.req.get_method(), "auth")
    end

    -- Parse as needed (call in pcall for safety)
    local status, call = pcall(cjson.decode, post_data)

    -- Did we fail parse?
    if call == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, unable to parse JSON object", "SYSTEM", ngx.req.get_method(), "auth")
    end

    if call.auth == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, missing auth object", "SYSTEM", ngx.req.get_method(), "auth")
    elseif call.auth.username == nil or call.auth.password == nil then
	return_error(r, "Username or password not set on request", "INVALID_LOGIN", "the username/password value is not valid", "SYSTEM", ngx.req.get_method(), "auth")
    elseif auth_user(call.auth.username, call.auth.password) then
	local new_token = new_session_token(call.auth.username)

	-- Setup session for this user
	ngx.header['Set-Cookie'] = 'ZDAPI_SESSID=' .. new_token .. '; path=/'
	session_dict:delete(call.auth.username)
	session_dict:add(new_token, call.auth.username, 3600 * 2)

	r.response.dbg_info.username = call.auth.username
	r.response.token = new_token
	return_response(r, "OK")
    else
	return_error(r, "No match found for user/pass", "INVALID_LOGIN", "the username/password value is not valid", "UNAUTH", ngx.req.get_method(), "auth")
    end

    return_error(r, "Unknown error", "INTERNAL_ERROR", "Unexpected error", "SYSTEM", ngx.req.get_method(), "auth")
end

function auth_check(service)
    local r = init_response()

    local user, token = get_auth_user()

    if token == nil then
	return_error(r, "missing auth token", "MISSING_AUTH", "missing auth token", "SYSTEM", ngx.req.get_method(), service)
    elseif user == nil then
	return_error(r, "auth token invalid", "NOAUTH", "Not authorized", "SYSTEM", ngx.req.get_method(), service)
    end

    return user
end

------------------------------------------------------------------------------
-- Database Functions
------------------------------------------------------------------------------

local function db_query(sql)
    local cfg = load_config()

    -- Test mysql
    local db, err = mysql:new()

    if not db then
	ngx.log(ngx.ERR, 'failed to create mysql object')
	return nil, 'failed to create mysql object', -1, -1
    end

    -- 1 second timeout
    db:set_timeout(1000)

    local emucfg = cfg['emu']

    local ok, err, errno, sqlstate = db:connect({
	host = emucfg['DBHost'],
	port = emucfg['DBPort'],
	database = emucfg['DBName'],
	user = emucfg['DBUser'],
	password = emucfg['DBPass'],
	max_packet_size = 1024 * 1024
    })

    if not ok then
	ngx.log(ngx.ERR, 'mysql connect failed: ' .. errno .. ': ' .. err .. ' (' .. sqlstate .. ')')
	return nil, err, errno, sqlstate
    end

    local res, err, errno, sqlstate = db:query(sql)

    if err then
	ngx.log(ngx.ERR, 'mysql query[' .. sql .. '] failed: ' .. errno .. ': ' .. err .. ' (' .. sqlstate .. ')')
	return nil, err, errno, sqlstate
    end

    db:set_keepalive(10000, 10)

    return res, err, errno, sqlstate
end

------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------
function service_version(path)
    local r = init_response()

    if ngx.req.get_method() == "GET" then
	r.response.version = api_version
	return_response(r, "OK")
    end

    return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Method is not accepted for this service", "SYSTEM", ngx.req.get_method(), "version")
end

function service_config(path)
    local u = auth_check('config')

    local r = init_response()

    if ngx.req.get_method() == "GET" then
	r.response.config = load_config()
	return_response(r, "OK")
    end

    if ngx.req.get_method() ~= "PUT" then
	return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Method is not accepted for the this service", "SYSTEM", ngx.req.get_method(), "config")
    end

    if u.admin_level < 15 then
	return_error(r, "PERMISSION DENIED", "PERMISSION_DENIED", "You are not allowed to update the configuration", "SYSTEM", ngx.req.get_method(), "config")
    end

    -- Make sure body is read in
    ngx.req.read_body()

    -- Get post_data
    local post_data = ngx.req.get_body_data()

    if post_data == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, missing body", "SYSTEM", ngx.req.get_method(), "config")
    end

    -- Parse as needed (call in pcall for safety)
    local status, call = pcall(cjson.decode, post_data)

    -- Did we fail parse?
    if call == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, unable to parse JSON object", "SYSTEM", ngx.req.get_method(), "config")
    end

    if call.config == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, missing config object", "SYSTEM", ngx.req.get_method(), "config")
    end

    -- Only support changing zones for now...
    -- Really we just "edit" the existing config file and uncomment or comment as needed.. 
    -- Expects the ZonesEnabled = { 
    -- array to be well formatted :-(
    --
    if call.config.emu and call.config.emu.ZonesEnabled then
	local cfg = load_config()

	local enableZones = { }

	for _, zone in pairs(call.config.emu.ZonesEnabled) do
	    enableZones[zone] = true
	end

	local src_fh, err = io.open(cfg.yoda.emuConfigPath)

	if err then
	    return_error(r, "Unknown error", "INTERNAL_ERROR", "Unexpected error: " .. err, "SYSTEM", ngx.req.get_method(), "config")
	end

	local dst_fh, err  = io.open(cfg.yoda.emuConfigPath .. ".new", "w")

	if err then
	    return_error(r, "Unknown error", "INTERNAL_ERROR", "Unexpected error: " .. err, "SYSTEM", ngx.req.get_method(), "config")
	end

	local inZones = false

	while true do
	    local ln = src_fh:read()

	    if ln == nil then break end

	    if inZones and string.match(ln, "^}") then
		inZones = false
	    end

	    if inZones then
		local ln_z = string.match(ln, '"([^"]+)"')

		if ln_z then
		    if enableZones[ln_z] then
			ln = string.gsub(ln, '^([ \t]+)--"', '%1"')
		    else
			ln = string.gsub(ln, '^([ \t]+)"', '%1--"')
		    end
		end
	    end

	    dst_fh:write(ln .. "\n")

	    if string.match(ln, "^ZonesEnabled = {") then
		inZones = true
	    end
	end

	src_fh:close()
	dst_fh:close()

	-- Swap files
	os.rename(cfg.yoda.emuConfigPath, cfg.yoda.emuConfigPath .. ".old")
	os.rename(cfg.yoda.emuConfigPath .. ".new", cfg.yoda.emuConfigPath)
    end

    return_response(r, "OK")
end

function service_status(path)
    -- Anyone can get status? They could just try and login to get status etc..
    local u, token = get_auth_user()

    local r = init_response()

    if ngx.req.get_method() == "GET" then
	local cfg = load_config()

	local pids = procps.pgrep_pidlist("core3")

	r.response['server_status'] = {
	    ["server_pid"] = pids[1] or "",
	    ["server_ip"] = cfg.yoda.server_ip,
	    ["login_port"] = cfg.emu.LoginPort,
	    ["autoreg"] = cfg.emu.AutoReg
	}

	if pids[1] then
	    local etime, err = procps.etime_string(pids[1])

	    if err then
		r.response.server_status.server_uptime = ""
		r.response.server_status.server_uptime_error = err
	    else
		r.response.server_status.server_uptime = etime
	    end
	end

	-- How many accounts do we have?
	local res, err, errno, sqlstate = db_query("SELECT COUNT(*) as `count` FROM `accounts`;")

	if res then
	    r.response.server_status.mysql_status = 'ok'
	    r.response.server_status.num_accounts = res[1]['count']
	else
	    r.response.server_status.mysql_status = errno .. ': ' .. err .. ' (' .. sqlstate .. ')'
	end

	if u then
	    r.response.server_status.account = { username = u.username, admin_level = u.admin_level }
	end

	return_response(r, "OK")
    end

    return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Method is not accepted for the this service", "SYSTEM", ngx.req.get_method(), "status")
end

function service_account()
    local r = init_response()

    -- GET account
    if ngx.req.get_method() == "GET" then
	local u = auth_check('account:' .. ngx.req.get_method())

	r.response["account"] = { username = u.username, admin_level = u.admin_level }

	return_response(r, "OK")
    end

    if ngx.req.get_method() ~= "POST" then
	return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Method is not accepted for the this service", "SYSTEM", ngx.req.get_method(), "config")
    end

    -- Only admins can create an account
    local u = auth_check('account:' .. ngx.req.get_method())

    if u.admin_level < 15 then
	return_error(r, "PERMISSION DENIED", "PERMISSION_DENIED", "You are not allowed to create new accounts", "SYSTEM", ngx.req.get_method(), "accont")
    end

    -- Yoda gets one chance to create and admin account, after that he's toast
    if u.account_id == -1 then
	local res, err, errno, sqlstate = db_query("SELECT COUNT(*) as `count` FROM `accounts` WHERE `admin_level` >= 15;")

	if res and tonumber(res[1].count) >= 1 then
	    return_error(r, "Must be admin to add accounts", "PERMISSION_DENIED", "Yoda is a one trick pony, please use an existing admin account to add new users.", "SYSTEM", ngx.req.get_method(), "account")
	end
    end

    -- Make sure body is read in
    ngx.req.read_body()

    -- Get post_data
    local post_data = ngx.req.get_body_data()

    if post_data == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, missing body", "SYSTEM", ngx.req.get_method(), "account")
    end

    -- Parse as needed (call in pcall for safety)
    local status, call = pcall(cjson.decode, post_data)

    -- Did we fail parse?
    if call == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, unable to parse JSON object", "SYSTEM", ngx.req.get_method(), "account")
    end

    if call.account == nil then
	return_error(r, "SYNTAX ERROR", "SYNTAX_ERROR", "Syntax error in request, missing account object", "SYSTEM", ngx.req.get_method(), "account")
    elseif call.account.username == nil then
	return_error(r, "Username not set on account object", "INVALID_OBJECT", "the username value is not valid", "SYSTEM", ngx.req.get_method(), "account")
    elseif call.account.password == nil or call.account.password == "" then
	return_error(r, "Password not set on account object", "INVALID_OBJECT", "the password value is not valid", "SYSTEM", ngx.req.get_method(), "account")
    end

    local res, err, errno, sqlstate = db_query("SELECT `account_id` FROM `accounts` WHERE `username` = " .. ngx.quote_sql_str(call.account.username))

    if res and #res > 0 then
	ngx.log(ngx.ERR, 'Duplicate account attempt?:' .. cjson.encode(res))
	return_error(r, "Username not available.", "EXISTING_USERNAME", "That username is already in use.", "SYSTEM", ngx.req.get_method(), "account")
    end

    local sql = "INSERT INTO `accounts` (`username`, `password`, `admin_level`) VALUES ("
    ..  ngx.quote_sql_str(call.account.username) .. ","
    ..  ngx.quote_sql_str(SHA1Hash(call.account.password)) .. ","
    ..  ngx.quote_sql_str(call.account.admin_level or 0)
    .. ")"

    local res, err, errno, sqlstate = db_query(sql)

    if err then
	return_error(r, "Unknown error", "INTERNAL_ERROR", "Unexpected error", "SYSTEM", ngx.req.get_method(), "account")
    end

    return_response(r, "OK")
end

function service_control(path)
    local cmd = ngx.var.arg_command or "status"

    local cfg = load_config()

    local u = auth_check('config')

    local r = init_response()

    if ngx.req.get_method() ~= "GET" then
	return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Method is not accepted for the this service", "SYSTEM", ngx.req.get_method(), "control")
    end

    local required_level = cfg.yoda.control_permission_level[cmd]

    if required_level == nil then
	return_error(r, "COMMAND NOT ENABLED", "INVALID_CONTROL_COMMAND", "This control command is not enabled on the server.", "SYSTEM", ngx.req.get_method(), "control")
    end

    if u.admin_level < required_level then
	return_error(r, "PERMISSION DENIED", "PERMISSION_DENIED", "You are not allowed to control the server", "SYSTEM", ngx.req.get_method(), "control")
    end

    local parts = { }

    if ngx.var.arg_arg1 then cmd = cmd .. " " .. ngx.var.arg_arg1 end
    if ngx.var.arg_arg2 then cmd = cmd .. " " .. ngx.var.arg_arg2 end

    ngx.log(ngx.ERR, "cmd=[" .. cmd .. "]")

    r.response = { output = "", command = cmd }

    local fh = io.popen(os.getenv("HOME") .. "/bin/swgemu --api " .. cmd)

    while true do
	local ln, err = fh:read("*l")

	if err then
	    r.response.error_message = err
	    break
	end

	if ln then
	    parts[#parts+1] = ln
	else
	    break
	end
    end

    r.response.output = table.concat(parts, "\n")

    return_response(r, "OK")
end

function service_console(path)
    local u = auth_check('console')
    local r = init_response()
    local cfg = load_config()

    if cfg.yoda.consoleLevelRead == nil or cfg.yoda.consoleLevelWrite == nil then
	local msg = "Missing consoleLevelRead and/or consoleLevelWrite in configuration."
	ngx.log(ngx.ERR, msg)
	return_error(r, "INVALID CONFIGURATION", "INVALID_CONFIG", msg, "SYSTEM", ngx.req.get_method(), "console")
    end

    if ngx.req.get_method() == "GET" then
	if u.admin_level < cfg.yoda.consoleLevelRead then
	    return_error(r, "PERMISSION DENIED", "PERMISSION_DENIED", "You are not allowed to view the console", "SYSTEM", ngx.req.get_method(), "console")
	end

	local readonly = true

	if u.admin_level >= cfg.yoda.consoleLevelWrite then
	    readonly = false
	end

	-- Handle websocket protocol
	websocket_console.run(readonly, 4096)

	ngx.exit(ngx.HTTP_OK)
    end

    return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Method is not accepted for the this service", "SYSTEM", ngx.req.get_method(), "console")
end

------------------------------------------------------------------------------
-- Intitialize API
------------------------------------------------------------------------------
function init()
end

local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
	ngx.log(ngx.ERR, 'attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)

_M.init()

-- vi: set ft=lua ai sw=2:
