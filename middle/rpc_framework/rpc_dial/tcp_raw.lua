--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")
local Log = require("middle.logger").newLogger("[RAW]", "error")

local Dial = {
    m_info = nil,
    m_data = nil -- support only one arg
}
Dial.__index = Dial

-- set arg only once
function Dial.newRequest(rpc_info, rpc_opt, rpc_args, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self.m_info = rpc_info
        self.m_data = rpc_args or rpc_body
        assert(type(self.m_data) == "string", "Only support string")
        return self
    end
end

function Dial.newResponse(rpc_info, rpc_opt, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self.m_info = rpc_info
        self.m_data = rpc_body
        assert(type(self.m_data) == "string", "Only support string")
        return self
    end
end

function Dial:makePackage()
    if self.m_data and self.m_data:len() <= 65536 then
        local len = self.m_data:len()
        -- 2 byte ahead for raw data
        return string.char(Bit.rshift(len, 8)) .. string.char(Bit.band(len, 0xff)) .. self.m_data
    else
        Log:error("Invalid data")
    end
end

return Dial
