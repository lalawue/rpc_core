--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local support_arch = { ["x86"]='', ["x64"]='' }
local support_os = { ["Linux"]='', ["OSX"]='', ["BSD"]='', ["Windows"]='' }
if jit and support_arch[jit.arch] and support_os[jit.os] then
    -- supported arch and os
else
    print("only support LuaJIT with arch [x86|x64], os [Linux|OSX|BSD|Windows]")
    os.exit(0)
end

-- detect params
local app_name = ...
local app_env_config = os.getenv("APP_ENV_CONFIG")

if app_env_config then
    print("APP_ENV_CONFIG: " .. app_env_config)
else
    app_env_config = "config/app_env.lua"
    print("APP_ENV_CONFIG: not set, use config.app_env instead")
end

-- detect app_env_config file exist
local fp = io.open(app_env_config)
if not fp then
    print("failed to open config:", app_env_config)
    os.exit(0)
else
    fp:close()
end

-- treat Class as keyword
require("base.scratch")
Class = require("base.middleclass")
AppEnv = dofile(app_env_config)
assert(AppEnv)

-- list apps if no app_name provide
if type(app_name) ~= "string" then
   local lfs = require("base.ffi_lfs")
   print("supported apps:")
   local _list_apps = function (path)
      if path:len() <= 0 then
        return
      end
      for fname in lfs.dir(path) do
         if fname and fname:len() > 2 then
            print("", fname)
         end
      end
   end
   _list_apps("apps")
   _list_apps(AppEnv.Config.APP_DIR)
   os.exit(0)
else
    package.path = package.path .. string.format(";apps/%s/?.lua", app_name)
    if AppEnv.Config.APP_DIR:len() > 0 then
        package.path = package.path .. string.format(";%s/%s/?.lua", AppEnv.Config.APP_DIR, app_name)
    end
end

-- setup tmp, data dir
if jit.os == "Windows" then
    os.execute("mkdir " .. AppEnv.Config.TMP_DIR .. " 2>nul")
    os.execute("mkdir " .. AppEnv.Config.DATA_DIR .. " 2>nul")
 else
    os.execute("mkdir -p " .. AppEnv.Config.TMP_DIR )
    os.execute("mkdir -p " .. AppEnv.Config.DATA_DIR )
 end

-- create app instance, app:initialize(...) then app:launch()
local app_clazz = loadfile( string.format("apps/%s/main.lua", app_name) )
if not app_clazz then
    app_clazz = loadfile( string.format("%s/%s/main.lua", AppEnv.Config.APP_DIR, app_name) )
end
local app_instance = app_clazz():new(...)
app_instance:launch()
