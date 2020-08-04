--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local CJson = require("cjson")
local HttpParser = require("middle.ffi_hyperparser")

local Parser = {
    _hp = nil, -- hyperparser
}
Parser.__index = Parser

function Parser.newRequest()
    local parser = setmetatable({}, Parser)
    parser._hp = HttpParser.createParser("REQUEST")
    return parser
end

function Parser.newResponse()
    local parser = setmetatable({}, Parser)
    parser._hp = HttpParser.createParser("RESPONSE")
    return parser
end

-- return ret_value, proto_info, data_table
-- the proto_info would be http_header_table
function Parser:process(data)
    local ret_value, state, http_tbl = self._hp:process(data)
    if ret_value < 0 then
        return ret_value
    end
    local proto_info = nil
    local json_object = nil
    if state == HttpParser.STATE_BODY_FINISH and http_tbl then
        if http_tbl.contents then
            local content = table.concat(http_tbl.contents)
            http_tbl.contents = nil
            json_object = CJson.decode(content)
        else
            json_object = {}
        end
        proto_info = http_tbl
    end
    return ret_value, proto_info, json_object
end

function Parser:destroy()
    if self._hp then
        self._hp:destroy()
        self._hp = nil
    end
end

return Parser
