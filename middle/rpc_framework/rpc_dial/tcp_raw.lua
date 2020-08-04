--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")
local Log = require("middle.logger").newLogger("[RAW]", "error")

local Dial = {
    _info = nil,
    _data = nil -- support only one arg
}
Dial.__index = Dial

-- set arg only once
function Dial.newRequest(rpc_info, rpc_opt, rpc_args, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self._info = rpc_info
        self._data = rpc_args or rpc_body
        assert(type(self._data) == "string", "Only support string")
        return self
    end
end

function Dial.newResponse(rpc_info, rpc_opt, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self._info = rpc_info
        self._data = rpc_body
        assert(type(self._data) == "string", "Only support string")
        return self
    end
end

function Dial:makePackage()
    if self._data and self._data:len() <= 65536 then
        local len = self._data:len()
        -- 2 byte ahead for raw data
        return string.char(Bit.rshift(len, 8)) .. string.char(Bit.band(len, 0xff)) .. self._data
    else
        Log:error("Invalid data")
    end
end

return Dial
