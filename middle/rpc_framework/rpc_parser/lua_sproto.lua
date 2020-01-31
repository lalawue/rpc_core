-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Sproto = require("middle.sproto")
local FileManager = require("middle.file_manager")

local SprotoParser = {
    m_info = nil,
    m_func_decode = nil,
    m_left_data = "",
}
SprotoParser.__index = SprotoParser

local _parser = nil

local function _initSproto()
    if _parser == nil then
        -- TODO: should consider share the spec
        local spec = FileManager.readAllContent(AppEnv.Config.SPROTO_SPEC)
        if spec then
            _parser = Sproto.parse( spec )
        end
    end
end

function SprotoParser.newRequest(rpc_info)
    _initSproto()
    local parser = setmetatable({}, SprotoParser)
    parser.m_info = rpc_info
    parser.m_func_decode = _parser.request_decode
    return parser
end

function SprotoParser.newResponse(rpc_info)
    _initSproto()    
    local parser = setmetatable({}, SprotoParser)
    parser.m_info = rpc_info
    parser.m_func_decode = _parser.response_decode
    return parser
end

-- return ret_value, proto_info, data_table
-- the proto_info would be http_header_table
function SprotoParser:process(data)
    if type(data) == "string" then
        self.m_left_data = self.m_left_data .. data
        local object, name_tag = self.m_func_decode(_parser, self.m_info.name, _parser.unpack(self.m_left_data))
        if object then
            name_tag = { ["name"] = self.m_info.name }
            self.m_left_data = ""
        else
            name_tag = nil
            object = nil
        end
        return 1, name_tag, object
    end
    return -1
end

function SprotoParser:destroy()
    self.m_left_data = ""
end

return SprotoParser