-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local support_arch = { ["x86"]='', ["x64"]='' }
local support_os = { ["Linux"]='', ["OSX"]='', ["BSD"]='' }
if jit and support_arch[jit.arch] and support_os[jit.os] then
   -- supported arch and os
else
   print("build binaries requires luarocks and LuaJIT, with arch [x86|x64], os [Linux|OSX|BSD], exit build !")
   os.exit(0)
end

local build_dir, uname = ...
local binary_dir = string.format("%s/../binaries/%s", build_dir, uname)

local fmt = string.format

local Build = {
   runCmd = function(self, cmd)
      print("cmd: ", cmd)
      os.execute(cmd)
   end,
   binaryName = function( self, name, is_luarocks )
      if jit.os == 'OSX' then
         return "lib" .. name .. ".dylib"
      else
         return luarocks and (name .. ".so") or ("lib" .. name .. ".so")
      end
   end,
   --
   -- 
   prepareCJsonLibrary = function( self, dir_name, name )
      print("-- begin build cjson -- ")
      local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/lua-cjson.git; fi; ", dir_name)
      local make_cmd = fmt("cd %s; if [ ! -f '%s.so' ]; then luarocks make --local ; fi;", dir_name, name)
      local copy_cmd = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name, true))
      self:runCmd( clone_cmd )
      self:runCmd( make_cmd )
      self:runCmd( copy_cmd )
      print("-- end -- \n")
   end,
   prepareHyperparserLibrary = function(self, dir_name, name)
      print("-- begin build hyperparser -- ")
      local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/hyperparser.git; fi;", dir_name)
      local make_cmd = fmt("cd %s; if [ ! -f '%s.so' ]; then luarocks make --local ; fi; ", dir_name, name)
      local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name, true))
      self:runCmd( clone_cmd )
      self:runCmd( make_cmd )
      self:runCmd( copy_binary )
      print("-- end -- \n")
   end,
   prepareDnsLibrary = function(self, dir_name, name)
      print("-- begin build mdns -- ")
      local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/m_dnscnt.git; cd %s; git submodule update --init --recursive; fi;",
                            dir_name, dir_name)
      local make_cmd = fmt("cd %s; if [ ! -f 'build/%s' ]; then make; fi; ", dir_name, self:binaryName(name, false))
      self:runCmd( clone_cmd )
      self:runCmd( make_cmd )
      local binaries = { "mfoundation", "mnet", "mdns"}
      for _, v in ipairs(binaries) do
         local libname = self:binaryName(v, false)
         local copy_binary = fmt("cd %s; cp build/%s %s/%s", dir_name, libname, binary_dir, libname)
         self:runCmd( copy_binary )
      end
      print("-- end -- \n")
   end,
   prepareSprotoLibrary = function (self, dir_name, name)
      print("-- begin build sproto -- ")
      local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/sproto.git; fi;", dir_name)
      local make_cmd = fmt("cd %s; if [ ! -f '%s' ]; then make LUA_JIT_INCLUDE_PATH=%s; fi; ", dir_name, self:binaryName(name, false), os.getenv("LUA_JIT_INCLUDE_PATH"))
      local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name, true))
      self:runCmd( clone_cmd )
      self:runCmd( make_cmd )
      self:runCmd( copy_binary )
      print("-- end -- \n")   
   end,
   prepareLpegLibrary = function (self, dir_name, name)
      print("-- begin build lpeg -- ")
      local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/lpeg.git; fi;", dir_name)
      local make_cmd = fmt("cd %s; if [ ! -f '%s' ]; then make LUA_JIT_INCLUDE_PATH=%s; fi; ", dir_name, self:binaryName(name, false), os.getenv("LUA_JIT_INCLUDE_PATH"))
      local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name, true))
      self:runCmd( clone_cmd )
      self:runCmd( make_cmd )
      self:runCmd( copy_binary )
      print("-- end -- \n")   
   end, 
}
Build.__index = Build

Build:prepareCJsonLibrary( 'lua-cjson', 'cjson' )
Build:prepareHyperparserLibrary( 'hyperparser', 'hyperparser' )
Build:prepareDnsLibrary( 'm_dnscnt', 'mdns')
Build:prepareSprotoLibrary( 'sproto', 'sproto' )
Build:prepareLpegLibrary( 'lpeg', 'lpeg' )
