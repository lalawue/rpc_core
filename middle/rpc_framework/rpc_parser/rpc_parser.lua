-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local HttpJson = require("rpc_framework.rpc_parser.http_json")
local LuaSproto = require("rpc_framework.rpc_parser.lua_sproto")
local Log = require("middle.logger").newLogger("[RPC]", "debug")

local RpcParser = {
   -- parse HTTP headers and data
   m_parser = nil
}
RpcParser.__index = RpcParser

local _all_parsers = {
   [AppEnv.Prototols.HTTP_JSON] = HttpJson,
   [AppEnv.Prototols.LUA_SPROTO] = LuaSproto,
}

function RpcParser.newRequest(rpc_info)
   local parser = _all_parsers[rpc_info.proto]
   if parser then
      local self = setmetatable({}, RpcParser)
      self.m_parser = parser.newRequest(rpc_info)
      return self
   else
      Log:error("failed to find parser %s", rpc_info.proto)
   end
end

function RpcParser.newResponse(rpc_info)
   local parser = _all_parsers[rpc_info.proto]
   if parser then
      local self = setmetatable({}, RpcParser)
      self.m_parser = parser.newResponse(rpc_info)
      return self
   else
      Log:error("failed to find parser %s", rpc_info.proto)
   end
end

-- return ret_value, proto_info, data_table
-- ret_value < 0 means error
-- proto_info would be something like http_header_table
function RpcParser:process(data)
   if not self.m_parser or not data then
      Log:error("rpc_parser process invalid param")
      return -1
   end
   return self.m_parser:process(data)
end

function RpcParser:destroy()
   if self.m_parser then
      self.m_parser:destroy()
      self.m_parser = nil
   end
end

return RpcParser
