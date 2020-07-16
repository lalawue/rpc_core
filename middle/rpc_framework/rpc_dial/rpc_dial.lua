--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local TcpRaw = require("rpc_framework.rpc_dial.tcp_raw")
local HttpJson = require("rpc_framework.rpc_dial.http_json")
local LuaSproto = require("rpc_framework.rpc_dial.lua_sproto")
local LuaResp = require("rpc_framework.rpc_dial.lua_resp")
local Log = require("middle.logger").newLogger("[RPC]", "error")

local RpcDial = {}
RpcDial.__index = RpcDial

local setmetatable = setmetatable

function RpcDial.new()
    local dial = {
        m_dial = nil
    }
    setmetatable(dial, RpcDial)
    return dial
end

local _all_dials = {
    [AppEnv.Prototols.TCP_RAW] = TcpRaw,
    [AppEnv.Prototols.HTTP_JSON] = HttpJson,
    [AppEnv.Prototols.LUA_SPROTO] = LuaSproto,
    [AppEnv.Prototols.LUA_RESP] = LuaResp,
}

-- rpc_args will encode as path in HTTP_JSON psec
function RpcDial:callMethod(rpc_info, rpc_opt, rpc_args, rpc_body)
    if rpc_info == nil then
        Log:error("invalid call method param")
        return
    end
    local dial = _all_dials[rpc_info.proto]
    if dial then
        self.m_dial = dial.newRequest(rpc_info, rpc_opt, rpc_args, rpc_body)
    else
        Log:error("failed to find dial %s", rpc_info.proto)
    end
end

function RpcDial:responseMethod(rpc_info, rpc_opt, rpc_body)
    if rpc_info == nil then
        Log:error("invalid response method param")
        return
    end
    local dial = _all_dials[rpc_info.proto]
    if dial then
        self.m_dial = dial.newResponse(rpc_info, rpc_opt, rpc_body)
    else
        Log:error("failed to find dial %s", rpc_info.proto)
    end
end

function RpcDial:makePackage(status_code, err_message)
    if self.m_dial == nil then
        Log:error("failed to make package for invalid dial object")
        return
    end
    return self.m_dial:makePackage(status_code, err_message)
end

return RpcDial
