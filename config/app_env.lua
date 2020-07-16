--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Sproto = require("middle.sproto")

-- App environment
local AppEnv = {}

local function _tmpDir()
    return jit.os == "Windows" and os.getenv("TMP") or "/tmp"
end

local function _parseSprotoSpec(file_path)
    print("I.[AppEnv] parse sproto spec " .. file_path)
    repeat
        local f = io.open(file_path, "rb")
        if not f then
            break
        end
        local spec_content = f:read("*a")
        f:close()
        if not spec_content then
            break
        end
        local bin_content = Sproto.parse(spec_content)
        if not bin_content then
            break
        end
        return bin_content
    until false
    print("E.[AppEnv] failed to parse sproto spec")
    os.exit(0)
end

-- define your app config
AppEnv.Config = {
    APP_DIR = "", -- app dir
    TMP_DIR = _tmpDir(), -- tmp dir
    DATA_DIR = _tmpDir() .. "/rpc_apps",
    LOOP_IPV4 = "127.0.0.1", -- loop ip
    HOST_IPV4 = "0.0.0.0", -- host ip
    RPC_TIMEOUT = 8, -- 8 second
}

AppEnv.Prototols = {
    TCP_RAW = "TCP_RAW", -- raw data in TCP, with 2 bytes length ahead
    HTTP_JSON = "HTTP_JSON", -- JSON in HTTP body
    LUA_SPROTO = "LUA_SPROTO", -- https://github.com/cloudwu/sproto, like protobuf, with 2 bytes length ahead
    LUA_RESP = "LUA_RESP" -- Redis Protocol specification 2
}

AppEnv.Store = {
    -- parse sproto spec first
    [AppEnv.Prototols.LUA_SPROTO] = _parseSprotoSpec("config/rpc_spec.sproto")
}

-- service info for publisher or caller
AppEnv.Service = {
    -- rpc_name = { name = "rpc_name", proto = 'AppEnv.Prototols', ipv4 = '127.0.0.1', port = 1024 }
    DNS_JSON = {
        name = "dns_json",
        proto = AppEnv.Prototols.HTTP_JSON,
        ipv4 = AppEnv.Config.LOOP_IPV4,
        port = 10053
    },
    DNS_SPROTO = {
        name = "dns_sproto", -- message name in sproto spec
        proto = AppEnv.Prototols.LUA_SPROTO,
        ipv4 = AppEnv.Config.LOOP_IPV4,
        port = 10054
    },
    LUA_RESP = {
        name = "resp_v2",
        proto = AppEnv.Prototols.LUA_RESP,
        ipv4 = AppEnv.Config.LOOP_IPV4,
        port = 6379
    }
}

-- set readonly mode
local err_message = "attempt to update AppEnv table"

AppEnv.Config = table.readonly(AppEnv.Config, err_message)
AppEnv.Prototols = table.readonly(AppEnv.Prototols, err_message)
AppEnv.Service = table.readonly(AppEnv.Service, err_message)
AppEnv.Store = table.readonly(AppEnv.Store, err_message)
AppEnv = table.readonly(AppEnv, err_message)

return AppEnv
