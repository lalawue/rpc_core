--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Bit = require("bit")

local SprotoParser = {
    m_info = nil,
    m_func = nil,
    m_data = "",
    m_len = nil
}
SprotoParser.__index = SprotoParser

local _parser = AppEnv.Store[AppEnv.Prototols.LUA_SPROTO]

function SprotoParser.newRequest(rpc_info)
    local parser = setmetatable({}, SprotoParser)
    parser.m_info = rpc_info
    parser.m_func = _parser.request_decode
    return parser
end

function SprotoParser.newResponse(rpc_info)
    local parser = setmetatable({}, SprotoParser)
    parser.m_info = rpc_info
    parser.m_func = _parser.response_decode
    return parser
end

-- return ret_value, proto_info, data_table
-- the proto_info would be http_header_table
function SprotoParser:process(data)
    if type(data) == "string" then
        self.m_data = self.m_data .. data
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
        local ret_decode, object, name_tag = pcall(self.m_func, _parser, self.m_info.name, content)
        if ret_decode then
            if object then
                name_tag = {["name"] = self.m_info.name}
                self.m_data = ""
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
    self.m_data = ""
    self.m_len = nil
end

return SprotoParser
