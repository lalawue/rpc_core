--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")
local Log = require("middle.logger").newLogger("[RAW]", "error")

local Parser = {
    _info = nil,
    _data = "",
    _len = nil
}
Parser.__index = Parser

function Parser.newRequest(rpc_info)
    local parser = setmetatable({}, Parser)
    parser._info = rpc_info
    return parser
end

function Parser.newResponse(rpc_info)
    local parser = setmetatable({}, Parser)
    parser._info = rpc_info
    return parser
end

local _proto_info = {}

-- return ret_value, proto_info, data_table
-- the proto_info would be empty_table
function Parser:process(data)
    if type(data) ~= "string" then
        Log:error("Invalid process data")
        return -1
    end
    print("process before append ", data:len())
    self._data = self._data .. data
    print("process after append ", self._data:len())
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
    return 1, _proto_info, content
end

function Parser:destroy()
    self._data = ""
    self._len = nil
end

return Parser
