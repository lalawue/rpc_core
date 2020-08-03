--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

--
-- raw tcp stated stream, interface should be same as tcp_ssl
--

local NetCore = require("base.ffi_mnet")
local Log = require("middle.logger").newLogger("[TcpRaw]", "error")

local ChannRaw = {
    m_options = nil,
    m_chann = nil,
    m_callback = nil
}
ChannRaw.__index = ChannRaw

local _has_init = false
function ChannRaw.openChann(options)
    if not _has_init then
        NetCore.init()
    end
    local chann = setmetatable({}, ChannRaw)
    chann.m_options = options
    chann.m_chann = NetCore.openChann("tcp")
    return chann
end

function ChannRaw:closeChann()
    if self.m_chann then
        self.m_chann:close()
        self.m_chann = nil
    end
end

function ChannRaw:connectAddr(ipv4, port)
    if self.m_chann and self.m_chann:state() ~= "state_connected" then
        self.m_chann:connect(ipv4, port)
        return true
    else
        Log:error("failed to connect '%s:%d', %s", ipv4, port, self.m_chann)
        return false
    end
end

-- callback params should be (self, event_name, accept_chann, c_msg)
function ChannRaw:setCallback(callback)
    if not callback then
        Log:error("invalid callback param")
        return
    end
    self.m_callback = callback
    self.m_chann:setCallback(
        function(chann, event_name, accept_chann, c_msg)
            if event_name == "event_connected" then
                self.m_callback(self, event_name, accept_chann, c_msg)
            elseif event_name == "event_recv" then
                self.m_callback(self, event_name, nil, c_msg)
            elseif event_name == "event_send" then
                self.m_callback(self, event_name, nil, c_msg)
            elseif event_name == "event_disconnect" then
                self.m_callback(self, event_name, nil, c_msg)
            elseif event_name == "event_accept" then
                local chann_raw = setmetatable({}, ChannRaw)
                chann_raw.m_chann = accept_chann
                self.m_callback(self, event_name, chann_raw, c_msg)
            end
        end
    )
end

function ChannRaw:send(data)
    if self.m_chann and self.m_chann:state() == "state_connected" then
        return self.m_chann:send(data)
    end
end

function ChannRaw:recv()
    if self.m_chann and self.m_chann:state() == "state_connected" then
        return self.m_chann:recv()
    end
end

function ChannRaw:onLoopEvent()
    return false
end

return ChannRaw
