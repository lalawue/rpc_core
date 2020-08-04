--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")

local SprotoParser = {
    _info = nil,
    _func = nil,
    _data = "",
    _len = nil
}
SprotoParser.__index = SprotoParser

local _parser = AppEnv.Store[AppEnv.Prototols.LUA_SPROTO]

function SprotoParser.newRequest(rpc_info)
    local parser = setmetatable({}, SprotoParser)
    parser._info = rpc_info
    parser._func = _parser.request_decode
    return parser
end

function SprotoParser.newResponse(rpc_info)
    local parser = setmetatable({}, SprotoParser)
    parser._info = rpc_info
    parser._func = _parser.response_decode
    return parser
end

-- return ret_value, proto_info, data_table
-- the proto_info would be http_header_table
function SprotoParser:process(data)
    if type(data) == "string" then
        self._data = self._data .. data
        if self._data:len() < 2 then
            return 0
        end
        if not self._len then
            local h8 = self._data:byte(1)
            local l8 = self._data:byte(2)
            self._len = Bit.lshift(h8, 8) + Bit.band(l8, 0xff)
            self._data = self._data:sub(3)
        end

        if self._data:len() < self._len then
            return 0
        end

        local content = self._data
        if content:len() > self._len then
            content = self._data:sub(1, self._len)
        end
        local ret_decode, object, name_tag = pcall(self._func, _parser, self._info.name, content)
        if ret_decode then
            if object then
                name_tag = {["name"] = self._info.name}
                self._data = ""
            else
                name_tag = nil
                object = nil
            end
            return 1, name_tag, object
        else
            return 0
        end
    end
    return -1
end

function SprotoParser:destroy()
    self._data = ""
    self._len = nil
end

return SprotoParser
