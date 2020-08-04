--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local support_arch = {["x86"] = "", ["x64"] = ""}
local support_os = {["Linux"] = "", ["OSX"] = "", ["BSD"] = "", ["Windows"] = ""}
if jit and support_arch[jit.arch] and support_os[jit.os] then
    -- supported arch and os
else
    print("only support LuaJIT with arch [x86|x64], os [Linux|OSX|BSD|Windows]")
    os.exit(0)
end

-- get app_name
local app_name = ...

-- get app_env_config
local env_config_path = os.getenv("APP_ENV_CONFIG")
if env_config_path then
    print("APP_ENV_CONFIG: " .. env_config_path)
else
    env_config_path = "config/app_env.lua"
    print("APP_ENV_CONFIG: not set, use config/app_env.lua instead")
end

-- detect app_env_config file exist
local fp = io.open(env_config_path)
if not fp then
    print("failed to open config:", env_config_path)
    os.exit(0)
else
    fp:close()
end

local function tracebackHandler(msg)
    print("\nPANIC : " .. tostring(msg) .. "\n")
    print(debug.traceback())
end

local status = false

-- treat Class as keyword
require("base.scratch")
Class = require("base.middleclass")

-- load AppEnv as global
status, AppEnv = xpcall(dofile, tracebackHandler, env_config_path)
if not status then
    os.exit(0)
else
    assert(AppEnv)
end

-- get apps_dir
local apps_dir = "apps"
if type(AppEnv.Config.APP_DIR) == "string" and string.len(AppEnv.Config.APP_DIR) > 0 then
    apps_dir = AppEnv.Config.APP_DIR
end

-- list apps if no app_name provide
if type(app_name) ~= "string" then
    local lfs = require("base.ffi_lfs")
    print("supported apps:")
    local _listApps = function(path)
        if path:len() <= 0 then
            return
        end
        for fname in lfs.dir(path) do
            local attr = lfs.attributes(path .. "/" .. fname)
            if attr.mode == "directory" and fname:len() > 2 and fname:sub(1, 1) ~= "." then
                print("", fname)
            end
        end
    end
    _listApps(apps_dir)
    os.exit(0)
else
    package.path = package.path .. string.format(";%s/%s/?.lua", apps_dir, app_name)
end

-- setup TMP_DIR, DATA_DIR
if jit.os == "Windows" then
    os.execute("mkdir " .. AppEnv.Config.TMP_DIR .. " 2>nul")
    os.execute("mkdir " .. AppEnv.Config.DATA_DIR .. " 2>nul")
else
    os.execute("mkdir -p " .. AppEnv.Config.TMP_DIR)
    os.execute("mkdir -p " .. AppEnv.Config.DATA_DIR)
end

-- create app instance, app:initialize(...) then app:launch()
local app_path = string.format("%s/%s/main.lua", apps_dir, app_name)
local st, app_clazz = xpcall(loadfile, tracebackHandler, app_path)
if st and app_clazz then
    local app_instance = app_clazz():new(...)
    app_instance:launch()
else
    print(string.format("\n[Launcher] failed to load '%s' from '%s'\n", app_name, apps_dir))
end
