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

local ChannSSL = {
    m_options = nil, -- not use now
    m_chann = nil, -- mnet chann
    m_ctx = nil, -- OpenSSL ctx
    m_ssl = nil, -- OpenSSL SSL handle
    m_ssl_connected = false, -- SSL connected state
    m_readed_data = "",
    m_write_data = ""
}
ChannSSL.__index = ChannSSL

-- only support client now
function ChannSSL.channSSL(name, options)
    if name == "client" then
        local chann_ssl = setmetatable({}, ChannSSL)
        chann_ssl.m_options = options
        chann_ssl.m_ctx = OpenSSL.ctx_new("SSLv23_client")
        chann_ssl.m_chann = NetCore.openChann("tcp")
        chann_ssl.m_chann:setCallback(
            function(chann, event_name, accept_chann, c_msg)
                ChannSSL.onClientCallback(chann_ssl, chann, event_name, accept_chann, c_msg)
            end
        )
        return chann_ssl
    end
    return nil
end

-- callback would be function(chann_ssl, event_name, accept_chann_ssl)
function ChannSSL:setCallback(callback)
    self.m_callback = callback
end

-- on mnet chann client callback
function ChannSSL:onClientCallback(chann, event_name, accept_chann, c_msg)
    if event_name == "event_connected" then
        local fd = chann:channFd()
        self.m_ssl = self.m_ctx:ssl(fd)
        self.m_ssl:set_connect_state()
    elseif event_name == "event_recv" then
        local buf, reason = self.m_ssl:read()
        if buf and self.m_callback then
            self.m_readed_data = self.m_readed_data .. buf
            self.m_callback(self, event_name, nil)
        end
    elseif event_name == "event_send" then
        if self.m_callback then
            self.m_callback(self, event_name, nil)
        end
    elseif event_name == "event_disconnect" then
        if self.m_callback then
            self.m_callback(self, event_name, nil)
        end
    end
end

-- for client
function ChannSSL:connect(ipv4, port)
    if self.m_ssl_connected then
        return
    end
    self.m_chann:connect(ipv4, port or 443)
end

-- for client
function ChannSSL:isConnected()
    return self.m_ssl_connected
end

-- handshake until connected
function ChannSSL:handshake()
    if self.m_ssl_connected then
        return true
    end
    local ret, reason = self.m_ssl:handshake()
    if not ret then
        if reason == "want_read" then
            -- disable send buffer empty event was enough
            self.m_chann:activeEvent("event_send", false)
        elseif reason == "want_write" then
            self.m_chann:activeEvent("event_send", true)
        end
    else
        self.m_ssl_connected = true
    end
    return self.m_ssl_connected
end

function ChannSSL:read()
    if not self.m_ssl_connected then
        return false
    end
    if self.m_readed_data:len() > 0 then
        local data = self.m_readed_data
        self.m_readed_data = ""
        return data
    else
        return nil
    end
end

function ChannSSL:write(data)
    if not self.m_ssl_connected then
        return false
    end
    self.m_write_data = self.m_write_data .. data
    local len = self.m_write_data:len()
    local number, reason = self.m_ssl:write(self.m_write_data)
    if number >= len then
        self.m_write_data = ""
    else
        self.m_write_data = self.m_write_data:sub(math.min(number, len) + 1)
    end
end

return ChannSSL
