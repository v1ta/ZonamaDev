--
-- api.lua - API to support EmuYoda web interface
--
-- Author: Lord Kator <lordkator@swgemu.com>
--
-- Created: Mon Jan 18 07:25:04 EST 2016
--

-- NOTES:
-- 
-- TODO: Auth lasts 2 hours and not attempt is made to check if pw was changed or acct banned in that time
-- TODO: Could use /api/auth to guess pw's should implement a tar pit
-- TODO: Config is loaded on each call to load_config() should consider caching
-- TODO: Currently 200 returned on all calls, maybe auth should return 4xx etc?
-- TODO: Long running commands via popen are bad idea, should stream, maybe to console websock or other channel
-- TODO: Yoda should go away after count(admin_level >= 15) is > 1 (basically it's only for that first launch and setup)
-- TODO: unit tests
-- TODO: Too big, need to break into smaller testable parts, maybe each service in a module and a common?

-- Globals we will want to reference in our module
local ngx = ngx or require "ngx"
local cjson = require "cjson"
local io = require "io"
local mysql = require "resty.mysql"
local procps = require "procps"
local resty_sha1 = require "resty.sha1"
local resty_sha256 = require "resty.sha256"
local resty_string = require "resty.string"
local ws_server = require "resty.websocket.server"
local websocket_console = require "websocket_console"
local assert = assert
local loadfile = loadfile
local math = math
local os = os
local package = package
local pairs = pairs
local pcall = pcall
local require = require
local setfenv = setfenv
local setmetatable = setmetatable
local string = string
local table = table
local tonumber = tonumber
local tostring = tostring
local session_dict = ngx.shared.session_dict
local status_dict = ngx.shared.status_dict

local api_version = "0.0.1"

module(...)

local yoda_config_path = os.getenv("HOME") .. '/server/emuyoda/yoda-config.lua'

local zonamadev_config_home = os.getenv("ZONAMADEV_CONFIG_HOME") or (os.getenv("HOME") .. "/.config/ZonamaDev")

------------------------------------------------------------------------------
-- Generic API helper functions
------------------------------------------------------------------------------
function init_response()
    return { response = { status = "ERROR", dbg_info = { instance = ngx.var.hostname, version = api_version, method = ngx.req.get_method() } } }
end

function return_response(r, status)
    r.response.status = status or "OK"
    if r.ws then
	local stash_ws = r.ws
	r.ws = nil
	r.response.dbg_info.is_websocket = true
	-- ngx.log(ngx.ERR, "return_response-WEBSOCKET:[" .. cjson.encode(r) .. "]")
	stash_ws:send_text(cjson.encode(r) .. "\n")
	r.ws = stash_ws
    else
	ngx.say(cjson.encode(r) .. "\n")
	ngx.exit(ngx.HTTP_OK)
    end
end

function return_error(r, error, error_code, error_description, error_id, method, service)
    r.response.error = error
    r.response.error_code = error_code
    r.response.error_description = error_description
    r.response.error_id = error_id
    r.response.method = method
    r.response.service = service
    return_response(r, "ERROR")

    if r.ws then
	r.ws:send_close()
	ngx.exit(ngx.HTTP_OK)
    end
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

function SHA256Hash(password)
    local sha256 = resty_sha256:new()

    sha256:update(password)

    return resty_string.to_hex(sha256:final())
end

------------------------------------------------------------------------------
-- Config functions
------------------------------------------------------------------------------
local function load_config()
    local f, err = io.open(yoda_config_path)

    if f == nil then
	ngx.log(ngx.ERR, 'load_config failed: yoda_config_path=[' .. yoda_config_path .. '] err=' .. err)
    end

    -- TODO Automatically load these from common/global.config

    local global_config = {
      ['ZDUSER']		= os.getenv("LOGNAME"),
      ['ZDHOME']		= os.getenv("HOME"),
      ['WORKSPACE']		= os.getenv("WORKSPACE") or os.getenv("HOME") .. '/workspace',
      ['RUN_DIR']		= os.getenv("RUN_DIR") or os.getenv("HOME") .. '/workspace/Core3/MMOCoreORB/bin',
      ['ZONAMADEV_CONFIG_HOME']	= zonamadev_config_home,
    }

    local yoda_cfg = setmetatable(global_config, {__index=_G})
    assert(pcall(setfenv(assert(loadfile(yoda_config_path)), yoda_cfg)))
    setmetatable(yoda_cfg, nil)

    yoda_cfg['__FILE__'] = yoda_config_path

    local emu_config_path = yoda_cfg['emuConfigPath']

    local fh = io.open(zonamadev_config_home .. "/config/server_ip")

    if fh then
	yoda_cfg.server_ip = fh:read("*l");
	fh:close();
    end

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
-- Authorization related functions
------------------------------------------------------------------------------
function get_auth_user()
    local cfg = load_config()

    local token = ngx.var.cookie_ZDAPI_SESSID or ngx.req.get_headers()['authorization'] or ngx.var.arg_token

    -- Localhost or server_ip w/o token logs in as yoda
    if token == nil and (ngx.var.remote_addr == '127.0.0.1' or (cfg.yoda.yodaHosts ~= nil and cfg.yoda.yodaHosts[ngx.var.remote_addr])) then
	token = cfg.yoda.yodaSecret
    end

    if token == nil then
	return nil, token
    end

    -- yodaSecret 
    if token == cfg.yoda.yodaSecret then
	local u = {
	    account_id = -1,
	    username = 'yoda',
	    password = 'unknowable',
	    station_id = -1,
	    created = '',
	    admin_level = 16,
	    salt = ''
	}

	if cfg.yoda.yodaHosts ~= nil and cfg.yoda.yodaHosts[ngx.var.remote_addr] then
	    u.admin_level = cfg.yoda.yodaHosts[ngx.var.remote_addr];
	end
	
	ngx.log(ngx.ERR, 'get_auth_user: found Yoda! admin_level=', u.admin_level)

	return u, token
    end

    local account_id = session_dict:get(token)

    if account_id then
	local resp, err, errno, sqlstate = db_query("SELECT * FROM `accounts` WHERE `account_id` = " .. ngx.quote_sql_str(account_id))

	if resp then
	    return resp[1], token
	else
	    ngx.log(ngx.ERR, 'Failed to find user for account_id=[' .. account_id .. ']: ' .. errno .. ': ' .. err .. ' (' .. sqlstate .. ')')
	    session_dict:delete(token)
	end
    end

    -- Kill old cookie if it's invalid
    if ngx.var.cookie_ZDAPI_SESSID then
	ngx.header['Set-Cookie'] = 'ZDAPI_SESSID=deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT'
    end

    return nil, token
end

function updateAccount(accountID)
    -- See: https://github.com/TheAnswer/Core3/blob/unstable/MMOCoreORB/src/server/login/account/AccountImplementation.cpp#L29
    local result, err, errno, sqlstate = db_query(
    	"SELECT a.active, a.admin_level, "
	.. "IFNULL((SELECT b.reason FROM account_bans b WHERE b.account_id = a.account_id AND b.expires > UNIX_TIMESTAMP() ORDER BY b.expires DESC LIMIT 1), ''), "
	.. "IFNULL((SELECT b.expires FROM account_bans b WHERE b.account_id = a.account_id AND b.expires > UNIX_TIMESTAMP() ORDER BY b.expires DESC LIMIT 1), 0), "
	.. "IFNULL((SELECT b.issuer_id FROM account_bans b WHERE b.account_id = a.account_id AND b.expires > UNIX_TIMESTAMP() ORDER BY b.expires DESC LIMIT 1), 0) "
	.. "FROM accounts a WHERE a.account_id = " .. ngx.quote_sql_str(accountID) .. " LIMIT 1;")

    if err then
	ngx.log(ngx.ERR, 'account_isActive db_query failed: account_id=[' .. accountID .. ']: ' .. errno .. ': ' .. err .. ' (' .. sqlstate .. ')')
	return nil, "Query failed: " .. err
    end

    if result == nil or #result ~= 1 then
	return nil, "No results in database for this account?"
    end

    return {
	isActive = result[1],
	admin_level = result[2],
	ban_reason = result[3],
	ban_expires = result[4],
	ban_admin = result[5],
    }, nil
end

function auth_user(username, password)
    local cfg = load_config()

    local users = db_query("SELECT * FROM `accounts` WHERE `username` = " .. ngx.quote_sql_str(username))

    if users == nil or #users == 0 then
	return false, nil
    end

    if #users > 1 then
	ngx.log(ngx.ERR, "auth_user found multiple user objects!!!: " .. cjson.encode(users));
	return false, nil
    end

    local user = users[1]
    
    if user == nil then
      ngx.log(ngx.ERR, "user object nil for username: " .. username)
      return false, nil
    end

    ngx.log(ngx.ERR, "user object: " .. cjson.encode(user));

    local accountStatus, err = updateAccount(user.account_id)

    if not accountStatus.isActive then
	ngx.log(ngx.ERR, "WARNING: Banned user attempted to login: " .. cjson.encode(user))
	return false, nil
    end

    local passwordHashed 

    if user.salt == "" then
	passwordHashed = SHA1Hash(password)
    else
	passwordHashed = SHA256Hash(cfg.emu.DBSecret .. password .. user.salt)
    end

    -- ngx.log(ngx.ERR, "user.password=[" .. user.password .. "] supplied=[" .. passwordHashed .. "]")

    if user.password == passwordHashed then
	return true, user
    end

    ngx.log(ngx.ERR, "Invalid password for user " .. username)

    return false, nil
end

function new_session_token(username)
    return string.sub(ngx.encode_base64(ngx.hmac_sha1(tostring(math.random()) .. "random" .. tostring(os.time()), "apikey" .. username)), 1, -2)
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
	    user.salt = nil
	    user.password = nil
	    user.station_id = nil
	    r.response.user = user
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
    end

    local success, user = auth_user(call.auth.username, call.auth.password)

    if success then
	local new_token = new_session_token(call.auth.username)

	-- Setup session for this user
	ngx.header['Set-Cookie'] = 'ZDAPI_SESSID=' .. new_token .. '; path=/'
	session_dict:delete(user.account_id)
	session_dict:add(new_token, user.account_id, 3600 * 2)

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

    if ngx.var.arg_websocket then
	ngx.log(ngx.ERR, "trying websocket")

	local ws, err = ws_server:new{
	    timeout = 1000,
	    max_payload_len = 65535
	}

	if err then
	    ngx.log(ngx.ERR, "failed to create new websocket: ", err)
	    return_error(r, "IO ERROR", "IO_ERROR", cmd .. ": I/O error creating websocket: " .. err, "SYSTEM", ngx.req.get_method(), "control")
	end

	-- Stash it for future use
	r.ws = ws
	ngx.log(ngx.ERR, "have websocket")
    end

    if ngx.req.get_method() ~= "GET" then
	return_error(r, "METHOD NOT SUPPORTED FOR THIS SERVICE", "INVALID_METHOD", "Method is not accepted for the this service", "SYSTEM", ngx.req.get_method(), "control")
    end

    local required_level = cfg.yoda.control_permission_level[cmd]

    if required_level == nil then
	return_error(r, "COMMAND NOT ENABLED", "INVALID_CONTROL_COMMAND", "The command '" .. cmd .. "' is not enabled on the server. Edit ~/server/emuyoda/yoda-config.lua to enable.", "SYSTEM", ngx.req.get_method(), "control")
    end

    if u.admin_level < required_level then
	return_error(r, "PERMISSION DENIED", "PERMISSION_DENIED", "You do not have permission to use the '" .. cmd .. "' command on the server.", "SYSTEM", ngx.req.get_method(), "control")
    end

    local parts = { }

    if ngx.var.arg_arg1 then cmd = cmd .. " " .. ngx.var.arg_arg1 end

    if ngx.var.arg_arg2 then cmd = cmd .. " " .. ngx.var.arg_arg2 end

    -- TODO is this enough to avoid injection attack?
    cmd = cmd:gsub("[`$()%c]", "")

    ngx.log(ngx.ERR, "cmd=[" .. cmd .. "]")

    r.response.output = ""
    r.response.command = cmd

    local fh = io.popen(os.getenv("HOME") .. "/ZonamaDev/fasttrack/bin/swgemu --api " .. cmd)

    while true do
	local ln, err = fh:read("*l")

	if err then
	    r.response.error_message = err
	    return_error(r, "IO ERROR", "IO_ERROR", cmd .. ": I/O error reading output: " .. err, "SYSTEM", ngx.req.get_method(), "control")
	end

	if ln then
	    -- ngx.log(ngx.ERR, "LN:[" .. ln .. "]")

	    if r.ws then
		r.response.output = ln
		return_response(r, "CONTINUE")
	    else
		parts[#parts+1] = ln
	    end
	else
	    -- ngx.log(ngx.ERR, "LN:NIL")
	    break
	end
    end

    r.response.output = table.concat(parts, "\n")

    return_response(r, "OK")

    if r.ws then
	r.ws:send_close()
    end
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
