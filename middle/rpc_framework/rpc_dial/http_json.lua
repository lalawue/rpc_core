-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local CJson = require("cjson")
local UrlCore = require("middle.url")

local Dail = {
    m_type = nil,
    m_info = nil, -- server info
    m_query = nil, -- query string
    m_method = nil, -- POST or PUT when brings data
    m_body = nil
}
Dail.__index = Dail

function Dail.newRequest(rpc_info, rpc_opt, rpc_args, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dail)
        self.m_type = "REQUEST"
        self.m_info = rpc_info
        if type(rpc_args) == "table" then
            self.m_query = "?" .. UrlCore.buildQuery(rpc_args)
         else
            self.m_query = ""
         end
         self.m_body = rpc_body
         self.m_method = type(rpc_opt) == "table" and rpc_opt["method"] or nil -- like PUT, UPDATE
        return self
    end
end

function Dail.newResponse(rpc_info, rpc_opt, rpc_body)
    if rpc_info then
        local self = setmetatable({}, Dail)
        self.m_type = "RESPONSE"
        self.m_info = rpc_info
        self.m_body = rpc_body
        return self
    end
end

local function _fixedHttpHeaderString()
    return "User-Agent: RpcDialv20200126\nContent-Type: application/json; charset=utf-8\n"
end

function Dail:makePackage(status_code, err_message)
    if self.m_type == nil then
        return
    end    
    local data = self.m_body and CJson.encode( self.m_body ) or ""
    if self.m_type == "REQUEST" then
       local http_method = "GET"
       if data:len() > 2 then
          if self.m_method then
             http_method = self.m_method
          else
             http_method = "POST"
          end
       end
       local path = self.m_info.name .. self.m_query
       local output = http_method .. " /" .. path .. " HTTP/1.1\n"
          .. _fixedHttpHeaderString()
          .. "Content-Length: " .. data:len() .. "\n\n"
          .. data
       return output
    else
       local code = status_code or 200
       local status_str = err_message or (code == 200 and "200 OK\n" or "403 Forbidden\n")
       local output = "HTTP/1.1 " .. status_str
          .. _fixedHttpHeaderString()
          .. "Content-Length: " .. data:len() .. "\n\n"
          .. data
       return output
    end
end

return Dail