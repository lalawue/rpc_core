--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local AppFramework = require("middle.app_framework")
local RpcFramework = require("middle.rpc_framework")
local Log = require("middle.logger").newLogger("[AgentRedis]", "info")

local App = Class("AgentRedis", AppFramework)

function App:initialize(app_name)
    self.m_app_name = app_name
    local protocol = AppEnv.Service.REDIS_SPROTO
    Log:info("init %s, try to connect '%s:%d'", app_name, protocol.ipv4, protocol.port)
end

function App:loadBusiness(rpc_framework)
    -- as client, do nothing here
end

function App:startBusiness(rpc_framework)
    local cmd_tbl = {'HMSET', 'myhash', 'hello', '"world"'}
    local ret, datas = rpc_framework.newRequest(AppEnv.Service.REDIS_SPROTO, {timeout = 8}, cmd_tbl)
    if ret then
        Log:info("send redis command '%s'", table.concat(cmd_tbl, " "))        
        Log:info("service response '%s'", datas)
    else
        Log:error("Please start redis-server in port %d", AppEnv.Service.REDIS_SPROTO.port)
    end
    os.exit(0)
end

return App