--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local TcpRaw = require("rpc_framework.rpc_parser.tcp_raw")
local HttpJson = require("rpc_framework.rpc_parser.http_json")
local LuaSproto = require("rpc_framework.rpc_parser.lua_sproto")
local LuaResp = require("rpc_framework.rpc_parser.lua_resp")
local Log = require("middle.logger").newLogger("[RPC]", "debug")

local RpcParser = {
    -- parse HTTP headers and data
    _parser = nil
}
RpcParser.__index = RpcParser

local _all_parsers = {
    [AppEnv.Prototols.TCP_RAW] = TcpRaw,
    [AppEnv.Prototols.HTTP_JSON] = HttpJson,
    [AppEnv.Prototols.LUA_SPROTO] = LuaSproto,
    [AppEnv.Prototols.LUA_RESP] = LuaResp,
}

function RpcParser.newRequest(rpc_info)
    local parser = _all_parsers[rpc_info.proto]
    if parser then
        local self = setmetatable({}, RpcParser)
        self._parser = parser.newRequest(rpc_info)
        return self
    else
        Log:error("failed to find parser %s", rpc_info.proto)
    end
end

function RpcParser.newResponse(rpc_info)
    local parser = _all_parsers[rpc_info.proto]
    if parser then
        local self = setmetatable({}, RpcParser)
        self._parser = parser.newResponse(rpc_info)
        return self
    else
        Log:error("failed to find parser %s", rpc_info.proto)
    end
end

-- return ret_value, proto_info, data_table
-- ret_value < 0 means error
-- proto_info would be something like http_header_table
function RpcParser:process(data)
    if not self._parser or not data then
        Log:error("rpc_parser process invalid param")
        return -1
    end
    return self._parser:process(data)
end

function RpcParser:destroy()
    if self._parser then
        self._parser:destroy()
        self._parser = nil
    end
end

return RpcParser
