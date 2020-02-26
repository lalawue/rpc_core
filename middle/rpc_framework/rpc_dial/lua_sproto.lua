--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")

local Dial = {
    m_info = nil,
    m_data = nil, -- support only one arg
    m_func = nil
}
Dial.__index = Dial

local _parser = AppEnv.Store[AppEnv.Prototols.LUA_SPROTO]

-- set arg only once
function Dial.newRequest(rpc_info, rpc_opt, rpc_args, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self.m_info = rpc_info
        self.m_data = rpc_args or rpc_body
        self.m_func = _parser.request_encode
        assert(self.m_func ~= nil, "Invalid encode function")
        return self
    end
end

function Dial.newResponse(rpc_info, rpc_opt, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self.m_info = rpc_info
        self.m_data = rpc_body
        self.m_func = _parser.response_encode
        return self
    end
end

function Dial:makePackage(_, _)
    if self.m_func and self.m_data then
        -- protoname as service_info.name
        local data = self.m_func(_parser, self.m_info.name, self.m_data)
        local len = data:len()
        -- 2 byte ahead for length
        return string.char(Bit.rshift(len, 8)) .. string.char(Bit.band(len, 0xff)) .. data
    end
end

return Dial
