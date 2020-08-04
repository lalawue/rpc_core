--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")

local Dial = {
    _info = nil,
    _data = nil, -- support only one arg
    _func = nil
}
Dial.__index = Dial

local _parser = AppEnv.Store[AppEnv.Prototols.LUA_SPROTO]

-- set arg only once
function Dial.newRequest(rpc_info, rpc_opt, rpc_args, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self._info = rpc_info
        self._data = rpc_args or rpc_body
        self._func = _parser.request_encode
        assert(self._func ~= nil, "Invalid encode function")
        return self
    end
end

function Dial.newResponse(rpc_info, rpc_opt, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dial)
        self._info = rpc_info
        self._data = rpc_body
        self._func = _parser.response_encode
        return self
    end
end

function Dial:makePackage(_, _)
    if self._func and self._data then
        -- protoname as service_info.name
        local data = self._func(_parser, self._info.name, self._data)
        local len = data:len()
        -- 2 byte ahead for length
        return string.char(Bit.rshift(len, 8)) .. string.char(Bit.band(len, 0xff)) .. data
    end
end

return Dial
