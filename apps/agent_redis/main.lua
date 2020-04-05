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
    local newRequest = rpc_framework.newRequest
    local PROTOCOL = AppEnv.Service.REDIS_SPROTO
    local opt = {timeout = AppEnv.Config.BROWSER_TIMEOUT, keep_alive = true}

    local ret = nil
    local datas = nil

    -- keep socket alive, reuse it with multiple redis command
    for i = 1, 5, 1 do
        local data_tbl = {"HMSET", "myhash", "hello", '"world"', "count", tostring(i)}
        ret, datas, opt.reuse_info = newRequest(PROTOCOL, opt, data_tbl)
        if ret and datas then
            Log:info("server response '%s'", datas)
        else
            table.dump(datas)
        end
        opt.keep_alive = (i + 1 < 5) -- close socket for last one
    end

    os.exit(0)
end

return App
