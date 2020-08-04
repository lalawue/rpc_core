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
    _options = nil,
    _chann = nil,
    _callback = nil
}
ChannRaw.__index = ChannRaw

local _has_init = false
function ChannRaw.openChann(options)
    if not _has_init then
        NetCore.init()
    end
    local chann = setmetatable({}, ChannRaw)
    chann._options = options
    chann._chann = NetCore.openChann("tcp")
    return chann
end

function ChannRaw:closeChann()
    if self._chann then
        self._chann:close()
        self._chann = nil
    end
end

function ChannRaw:connectAddr(ipv4, port)
    if self._chann and self._chann:state() ~= "state_connected" then
        self._chann:connect(ipv4, port)
        return true
    else
        Log:error("failed to connect '%s:%d', %s", ipv4, port, self._chann)
        return false
    end
end

-- callback params should be (self, event_name, accept_chann, c_msg)
function ChannRaw:setCallback(callback)
    if not callback then
        Log:error("invalid callback param")
        return
    end
    self._callback = callback
    self._chann:setCallback(
        function(chann, event_name, accept_chann, c_msg)
            if event_name == "event_connected" then
                self._callback(self, event_name, accept_chann, c_msg)
            elseif event_name == "event_recv" then
                self._callback(self, event_name, nil, c_msg)
            elseif event_name == "event_send" then
                self._callback(self, event_name, nil, c_msg)
            elseif event_name == "event_disconnect" then
                self._callback(self, event_name, nil, c_msg)
            elseif event_name == "event_accept" then
                local chann_raw = setmetatable({}, ChannRaw)
                chann_raw._chann = accept_chann
                self._callback(self, event_name, chann_raw, c_msg)
            end
        end
    )
end

function ChannRaw:send(data)
    if self._chann and self._chann:state() == "state_connected" then
        return self._chann:send(data)
    end
end

function ChannRaw:recv()
    if self._chann and self._chann:state() == "state_connected" then
        return self._chann:recv()
    end
end

function ChannRaw:onLoopEvent()
    return false
end

return ChannRaw
