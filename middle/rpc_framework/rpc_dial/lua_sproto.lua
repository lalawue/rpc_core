-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Sproto = require("middle.sproto")
local FileManager = require("middle.file_manager")

local Dial = {
    m_info = nil,
    m_body = nil, -- support only one arg
    m_encode = nil,    
}
Dial.__index = Dial

local _parser = nil

local function _initParser()
    if _parser == nil then
       -- TODO: should consider share the spec
       local spec = FileManager.readAllContent(AppEnv.Config.SPROTO_SPEC)
       if spec then
           _parser = Sproto.parse( spec )
       end        
    end    
end

-- set arg only once
function Dial.newRequest(rpc_info, rpc_opt, rpc_args, rpc_body)
    if rpc_info then
        _initParser()
        local self = setmetatable({}, Dial)
        self.m_info = rpc_info
        self.m_body = rpc_args or rpc_body
        self.m_encode = _parser.request_encode
        return self
    end
end

function Dial.newResponse(rpc_info, rpc_opt, rpc_body)
    if rpc_info then
        _initParser()
        local self = setmetatable({}, Dial)
        self.m_info = rpc_info
        self.m_body = rpc_body
        self.m_encode = _parser.response_encode
        return self
    end
end

function Dial:makePackage(_, _)
    if self.m_encode and self.m_body then
        -- protoname as service_info.name
        return _parser.pack(self.m_encode(_parser, self.m_info.name, self.m_body))
    end
end

return Dial