--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

--
-- channel read/write with SSL/TLS base on mnet tcp
--
-- document: https://zhaozg.github.io/lua-openssl/modules/ssl.html#ctx_new
--

local NetCore = require("base.ffi_mnet")
local ret, OpenSSL = pcall(require, "openssl") -- consider not exist openssl library
local Log = require("middle.logger").newLogger("[TcpSSL]", "error")
if ret then
    OpenSSL = OpenSSL.ssl
else
    return false -- OpenSSL module not ready
end

local ChannSSL = {
    _options = nil, -- not use now
    _chann = nil, -- mnet chann
    _ctx = nil, -- OpenSSL ctx
    _ssl = nil, -- OpenSSL SSL handle
    _ssl_connected = false, -- SSL connected state
    _rfifo = nil, -- read fifo
    _wfifo = "" -- write fifo
}
ChannSSL.__index = ChannSSL

-- only support client now
function ChannSSL.openChann(options)
    if type(options) == "table" and options.protocol == "server" then
        Log:error("invalid option, not supported now")
    else
        local chann = setmetatable({}, ChannSSL)
        chann._options = options
        chann._ctx = OpenSSL.ctx_new("TLS") -- use ‘TLS’ to negotiate highest available SSL/TLS version
        chann._chann = NetCore.openChann("tcp")
        return chann
    end
end

function ChannSSL:closeChann()
    if self._chann then
        self._chann:close()
        self._chann = nil
    end
    if self._ssl then
        self._ssl:shutdown()
        self._ssl = nil
    end
    if self._ctx then
        self._ctx = nil
    end
    self._options = nil
    self._ssl_connected = false
    self._rfifo = nil
    self._wfifo = ""
end

-- for client
function ChannSSL:connectAddr(ipv4, port)
    if self._chann and self._chann:state() ~= "state_connected" then
        self._chann:connect(ipv4, port)
        return true
    else
        Log:error("failed to connect '%s:%d', %s", ipv4, port, self._chann)
        return false
    end
end

-- callback params should be (self, event_name, accept_chann, c_msg)
function ChannSSL:setCallback(callback)
    if not callback then
        Log:error("invalid callback param")
        return
    end
    self._callback = callback
    self._chann:setCallback(
        function(chann, event_name, accept_chann, c_msg)
            if event_name == "event_connected" then
                -- 'event_connected' callback in self:onLoopEvent()
                local fd = chann:channFd()
                self._ssl = self._ctx:ssl(fd)
                self._ssl:set_connect_state()
            elseif event_name == "event_recv" then
                local data, reason = self._ssl:read()
                if data then
                    self._rfifo = data
                    self._callback(self, event_name, accept_chann, c_msg)
                end
            elseif event_name == "event_send" then
                self._callback(self, event_name, accept_chann, c_msg)
            elseif event_name == "event_disconnect" then
                self._callback(self, event_name, accept_chann, c_msg)
            elseif event_name == "event_timer" then
                self._callback(self, event_name, accept_chann, c_msg)
            elseif event_name == "event_accept" then
            -- not supported 'server_protocol'
            end
        end
    )
end

function ChannSSL:send(data)
    if not self._ssl_connected then
        Log:error("failed to send for ssl not connected")
        return false
    end
    self._wfifo = self._wfifo .. data
    local len = self._wfifo:len()
    local number, reason = self._ssl:write(self._wfifo)
    if number >= len then
        self._wfifo = ""
    else
        self._wfifo = self._wfifo:sub(math.max(number, 0) + 1)
    end
    return true
end

function ChannSSL:recv()
    if not self._ssl_connected then
        Log:error("failed to recv for ssl not connected")
        return false
    end
    if self._rfifo then
        local data = self._rfifo
        self._rfifo = nil
        return data
    end
end

-- SSL handshake
function ChannSSL:handshake()
    if not self._ssl then
        return false
    end
    local ret, reason = self._ssl:handshake()
    if not ret then
        if reason == "want_read" then
            -- disable send buffer empty event was enough
            self._chann:activeEvent("event_send", false)
        elseif reason == "want_write" then
            self._chann:activeEvent("event_send", true)
        end
        return false
    end
    return true
end

function ChannSSL:setEventTimer(timeout_second)
    if self._chann then
        self._chann:activeEvent("event_timer", timeout_second * 1000000)
    end
end

function ChannSSL:onLoopEvent()
    if not self._ssl_connected then
        self._ssl_connected = self:handshake()
        if self._ssl_connected then
            self._callback(self, "event_connected", nil, nil)
            return true -- remove on loop event
        end
    end
    return false -- keep event
end

return ChannSSL
