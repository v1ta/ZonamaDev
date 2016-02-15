--
-- websocket_console.lua - Websocket interface to console
--
-- Author: Lord Kator <lordkator@swgemu.com>
--
-- Created: Fri Jan 22 17:42:18 EST 2016
--

-- Globals we will want to reference in our module
local ngx = ngx or require "ngx"
local cjson = require "cjson"
local io = require "io"
local ws_server = require "resty.websocket.server"
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

module(...)

local console_log = os.getenv("HOME") .. "/workspace/Core3/MMOCoreORB/bin/screenlog.0"

local function get_pid()
    local found = procps.pgrep_pidlist("core3")

    if #found > 1 then
	ngx.log(ngx.ERR, "WARNING: Multiple copies of core running?")
    end

    return found[1]
end

function run(readonly, tail_bytes, start_message)
    local wb, err = ws_server:new{
	timeout = 1000,
	max_payload_len = 16 * 1204
    }

    if not wb then
	ngx.log(ngx.ERR, "failed to create new websocket: ", err)
	return ngx.exit(444)
    end

    if start_message then
	wb:send_text(start_message .. "\n")
    end

    local pos, console_fh
    local pid = get_pid()

    while true do
	if console_fh == nil and (pos == nil or pid ~= nil)  then
	    console_fh = io.open(console_log, 'rb')

	    if console_fh then
		wb:send_text(">> Opened screenlog.0 <<")

		pos = 0

		if tail_bytes then
		    pos = console_fh:seek("end")

		    if pos > tail_bytes then
			pos = pos - tail_bytes
			wb:send_text("..skip " .. pos .. " bytes..\n")
		    end
		end
	    end
	end

	if console_fh then
	    console_fh:seek("set", pos)

	    -- for ln in console_fh:lines() do
	    while true do
		local ln = console_fh:read(1024)

		if ln == nil then
		    break
		end

		-- ln = string.gsub(string.gsub(ln, "\r$", ""), ".*\r", "")
		ln = string.gsub(string.gsub(ln, "\r\n", "\n"), "\r", "\n")

		local bytes, err = wb:send_text(ln)

		if err then
		    ngx.log(ngx.ERR, "failed to send a text frame: ", err)
		    return ngx.exit(446)
		end
	    end

	    pos = console_fh:seek()
	end

	if pid == nil then
	    if console_fh then
		console_fh = nil
		wb:send_text(">> Server not running <<")
	    end

	    pid = get_pid()

	    if pid then
		wb:send_text(">> Server started on PID " .. pid .. " <<")
		ngx.log(ngx.INFO, "server pid:", pid)
	    end
	else
	    local fh = io.open("/proc/" .. pid .. "/cmdline")

	    if fh then
		local ln = fh:read("*l")

		if not string.find(ln, ".*/core3$") then
		    pid = nil
		end

		fh:close()
	    else
		pid = nil
	    end

	    if pid == nil then
		ngx.log(ngx.INFO, "server stopped running")
	    end
	end

	local data, typ, err = wb:recv_frame()

	if wb.fatal then
	    ngx.log(ngx.ERR, "failed to receive frame: ", err)
	    return ngx.exit(447)
	end

	if typ == "close" then
	    ngx.log(ngx.ERR, "client requested close")
	    wb:send_close(1000, "client requested close")
	    break
	elseif typ == "ping" then
	    local bytes, err = wb:send_pong()
	    if not bytes then
		ngx.log(ngx.ERR, "failed to send pong: ", err)
		return ngx.exit(448)
	    end
	elseif typ == "pong" then
	    ngx.log(ngx.INFO, "client ponged")
	elseif typ == "text" then
	    ngx.log(ngx.INFO, "WARNING: client sent[" .. data .. "]")
	    --[[
	    -- They should use the /api/control?command=send
	    if readonly then
		wb:send_text(">> SEND [" .. data .. "] PERMISSION DENIED");
	    else
		-- TODO escape dangerous chars could end up being a server backdoor by accident here (backticks, $( etc.)
		os.execute("screen -S swgemu-server -X stuff '" .. data .. "^M'")
		wb:send_text(">> SEND: " .. data .. "\n")
	    end
	    ]]
	elseif typ ~= nil then
	    ngx.log(ngx.INFO, "received a frame of type ", typ, " and payload ", data)
	end
    end
    wb:send_close()
end

local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
	ngx.log(ngx.ERR, 'attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)

-- vi: set ft=lua ai sw=2:
