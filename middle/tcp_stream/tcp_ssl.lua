--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

--
-- channel read/write with SSL/TLS base on mnet tcp
--

local NetCore = require("base.ffi_mnet")
local OpenSSL = require("openssl").ssl
local Log = require("middle.logger").newLogger("[TcpSSL]", "error")

local ChannSSL = {
    m_options = nil, -- not use now
    m_chann = nil, -- mnet chann
    m_ctx = nil, -- OpenSSL ctx
    m_ssl = nil, -- OpenSSL SSL handle
    m_ssl_connected = false, -- SSL connected state
    m_read_fifo = "",
    m_write_fifo = ""
}
ChannSSL.__index = ChannSSL

-- only support client now
function ChannSSL.openChann(options)
    if type(options) == "table" and options.protocol == "server" then
        Log:error("invalid option, not supported now")
    else
        local chann = setmetatable({}, ChannSSL)
        chann.m_options = options
        chann.m_ctx = OpenSSL.ctx_new("SSLv23_client")
        chann.m_chann = NetCore.openChann("tcp")
        return chann
    end
end

function ChannSSL:closeChann()
    if self.m_chann then
        self.m_chann:close()
        self.m_chann = nil
    end
    if self.m_ssl then
        self.m_ssl:shutdown()
        self.m_ssl = nil
    end
    if self.m_ctx then
        self.m_ctx = nil
    end
    self.m_options = nil
    self.m_ssl_connected = false
    self.m_read_fifo = ""
    self.m_write_fifo = ""
end

-- for client
function ChannSSL:connectAddr(ipv4, port)
    if self.m_chann and self.m_chann:state() ~= "state_connected" then
        self.m_chann:connect(ipv4, port)
        return true
    else
        Log:error("failed to connect '%s:%d', %s", ipv4, port, self.m_chann)
        return false
    end
end

-- callback params should be (self, event_name, accept_chann, c_msg)
function ChannSSL:setCallback(callback)
    if not callback then
        Log:error("invalid callback param")
        return
    end
    self.m_callback = callback
    self.m_chann:setCallback(
        function(chann, event_name, accept_chann, c_msg)
            if event_name == "event_connected" then
                -- 'event_connected' callback in self:onLoopEvent()
                local fd = chann:channFd()
                self.m_ssl = self.m_ctx:ssl(fd)
                self.m_ssl:set_connect_state()
            elseif event_name == "event_recv" then
                local data, reason = self.m_ssl:read()
                if data then
                    self.m_read_fifo = self.m_read_fifo .. data
                    self.m_callback(self, event_name, accept_chann, c_msg)
                end
            elseif event_name == "event_send" then
                self.m_callback(self, event_name, accept_chann, c_msg)
            elseif event_name == "event_disconnect" then
                self.m_callback(self, event_name, accept_chann, c_msg)
            elseif event_name == "event_accept" then
            -- not supported 'server_protocol'
            end
        end
    )
end

function ChannSSL:send(data)
    if not self.m_ssl_connected then
        Log:error("failed to send for ssl not connected")
        return false
    end
    self.m_write_fifo = self.m_write_fifo .. data
    local len = self.m_write_fifo:len()
    local number, reason = self.m_ssl:write(self.m_write_fifo)
    if number >= len then
        self.m_write_fifo = ""
    else
        self.m_write_fifo = self.m_write_fifo:sub(math.min(number, len) + 1)
    end
    return true
end

function ChannSSL:recv()
    if not self.m_ssl_connected then
        Log:error("failed to recv for ssl not connected")
        return false
    end
    if self.m_read_fifo:len() > 0 then
        local data = self.m_read_fifo
        self.m_read_fifo = ""
        return data
    end
end

-- SSL handshake
function ChannSSL:handshake()
    if not self.m_ssl then
        return false
    end
    local ret, reason = self.m_ssl:handshake()
    if not ret then
        if reason == "want_read" then
            -- disable send buffer empty event was enough
            self.m_chann:activeEvent("event_send", false)
        elseif reason == "want_write" then
            self.m_chann:activeEvent("event_send", true)
        end
        return false
    end
    return true
end

-- event_name always "event_loop"
function ChannSSL:onLoopEvent(event_name)
    if not self.m_ssl_connected then
        self.m_ssl_connected = self:handshake()
        if self.m_ssl_connected then
            self.m_callback(self, "event_connected", nil, nil)
        end
    end
end

return ChannSSL
