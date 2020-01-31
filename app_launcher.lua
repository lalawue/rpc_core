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
   print("only support LuaJIT with arch [x86|x64], os [Linux|OSX|BSD]")
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

if type(app_name) ~= "string" then
   local lfs = require("base.ffi_lfs")
   print("supported apps:")
   for fname in lfs.dir("apps") do
      if fname and fname:len() > 2 then
         print("", fname)
      end
   end
   os.exit(0)
end

-- treat Class as keyword
require("base.scratch")
Class = require("base.middleclass")
AppEnv = dofile(app_env_config)

-- setup dir
if jit.os == "Windows" then
    os.execute("mkdir " .. AppEnv.Config.TMP_DIR .. " 2>nul")
    os.execute("mkdir " .. AppEnv.Config.DATA_DIR .. " 2>nul")
 else
    os.execute("mkdir -p " .. AppEnv.Config.TMP_DIR )
    os.execute("mkdir -p " .. AppEnv.Config.DATA_DIR )
 end

-- create app instance, app:initialize(...) then app:launch()
local app_clazz = require("apps." .. app_name)
local app_instance = app_clazz:new(...)
app_instance:launch()
