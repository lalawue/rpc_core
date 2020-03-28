--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local CJson = require("cjson")
local HttpParser = require("middle.ffi_hyperparser")

local Parser = {
    m_hp = nil, -- hyperparser
    m_left_data = nil
}
Parser.__index = Parser

function Parser.newRequest()
    local parser = setmetatable({}, Parser)
    parser.m_hp = HttpParser.createParser("REQUEST")
    return parser
end

function Parser.newResponse()
    local parser = setmetatable({}, Parser)
    parser.m_hp = HttpParser.createParser("RESPONSE")
    return parser
end

-- return ret_value, proto_info, data_table
-- the proto_info would be http_header_table
function Parser:process(data)
    if self.m_left_data then
        data = self.m_left_data .. data
        self.m_left_data = nil
    end
    local ret_value, state, header_tbl = self.m_hp:process(data)
    if ret_value < 0 then
        return ret_value
    end
    if ret_value > 0 and ret_value < data:len() then
        self.m_left_data = data:sub(ret_value + 1)
    end
    local proto_info = nil
    local json_object = nil
    if state == HttpParser.STATE_BODY_FINISH and header_tbl then
        if header_tbl.contents then
            local content = table.concat(header_tbl.contents)
            header_tbl.contents = nil
            json_object = CJson.decode(content)
        else
            json_object = {}
        end
        proto_info = header_tbl
    end
    return ret_value, proto_info, json_object
end

function Parser:destroy()
    if self.m_hp then
        self.m_hp:destroy()
        self.m_hp = nil
    end
    self.m_left_data = nil
end

return Parser
