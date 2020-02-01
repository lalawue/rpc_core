-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

-- App environment
local AppEnv = {}

local function _tmpDir()
    return jit.os == "Windows" and os.getenv("TMP") or "/tmp"
end

-- define your app config
AppEnv.Config = {
    APP_DIR = "",                -- user defined app dir
    TMP_DIR = _tmpDir(),         -- tmp dir
    DATA_DIR = _tmpDir() .. "/rpc_framework",
    LOOP_IPV4 = '127.0.0.1',     -- loop ip
    HOST_IPV4 = '127.0.0.1',     -- host ip
    RPC_LOOP_CHECK = 8,          -- loop count to check timeout
    BROWSER_TIMEOUT = 8,         -- not precise timeout
    SPROTO_SPEC = "config/app_rpc_spec.sproto",
}

AppEnv.Prototols = {
    HTTP_JSON = "HTTP_JSON", -- JSON in HTTP body
    LUA_SPROTO = "SPROTO", -- https://github.com/cloudwu/sproto, like protobuf
}

-- service info for publisher or caller
AppEnv.Service = {
   -- rpc_name = { name = "rpc_name", proto = 'AppEnv.Prototols', ipv4 = '127.0.0.1', port = 1024 }
   DNS_JSON = { name = "dns_json", proto = AppEnv.Prototols.HTTP_JSON, ipv4 = AppEnv.Config.HOST_IPV4, port = 10053 },
   DNS_SPROTO = { name = "dns_sproto", proto = AppEnv.Prototols.LUA_SPROTO, ipv4 = AppEnv.Config.LOOP_IPV4, port = 10054 },
}

-- set readonly mode
local err_message = "attempt to update AppEnv table"

AppEnv.Config = table.readonly(AppEnv.Config, err_message)
AppEnv.Prototols = table.readonly(AppEnv.Prototols, err_message)
AppEnv.Service = table.readonly(AppEnv.Service, err_message)
AppEnv = table.readonly(AppEnv, err_message)

return AppEnv