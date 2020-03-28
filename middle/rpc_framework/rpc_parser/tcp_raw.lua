--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")
local Log = require("middle.logger").newLogger("[RAW]", "error")

local Parser = {
    m_info = nil,
    m_data = "",
    m_len = nil
}
Parser.__index = Parser

function Parser.newRequest(rpc_info)
    local parser = setmetatable({}, Parser)
    parser.m_info = rpc_info
    return parser
end

function Parser.newResponse(rpc_info)
    local parser = setmetatable({}, Parser)
    parser.m_info = rpc_info
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
    self.m_data = self.m_data .. data
    print("process after append ", self.m_data:len())
    if self.m_data:len() < 2 then
        return 0
    end
    if not self.m_len then
        local h8 = self.m_data:byte(1)
        local l8 = self.m_data:byte(2)
        self.m_len = Bit.lshift(h8, 8) + Bit.band(l8, 0xff)
        self.m_data = self.m_data:sub(3)
    end

    if self.m_data:len() < self.m_len then
        return 0
    end

    local content = self.m_data
    if content:len() > self.m_len then
        content = self.m_data:sub(1, self.m_len)
    end
    return 1, _proto_info, content
end

function Parser:destroy()
    self.m_data = ""
    self.m_len = nil
end

return Parser
