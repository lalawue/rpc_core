--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local support_arch = {["x86"] = "", ["x64"] = ""}
local support_os = {["Linux"] = "", ["OSX"] = "", ["BSD"] = ""}
if jit and support_arch[jit.arch] and support_os[jit.os] then
    -- supported arch and os
else
    os.exit(0)
end

local build_dir, uname = ...
local binary_dir = string.format("%s/../binaries/%s", build_dir, uname)

local fmt = string.format

local Build = {
    CC = os.getenv("CC"),
    CFLAGS = os.getenv("CFLAGS"),
    MAKE = os.getenv("MAKE"),
    INCPTH = os.getenv("LUA_JIT_INCLUDE_PATH") or "/usr/local/include/luajit-2.0/",
    LIBPATH = os.getenv("LD_LIBRARY_PATH") or os.getenv("DYLD_LIBRARY_PATH") or "/usr/local/lib",
    LIBNAME = os.getenv("LUA_JIT_LIBRARY_NAME") or "luajit-5.1",
    PKGPATH = os.getenv("PKG_CONFIG_PATH"),
    --
    --
    setupToolchain = function(self)
        if not self.CC or self.CC:len() <= 0 then
            self.CC = jit.os == "BSD" and "cc" or "gcc"
        end
        if not self.CFLAGS or self.CFLAGS:len() <= 0 then
            self.CFLAGS = jit.os == "Darwin" and "-O3 -bundle -undefined dynamic_lookup" or "-O3 -shared -fPIC"
        end
        if not self.MAKE or self.MAKE:len() <= 0 then
            self.MAKE = jit.os == "BSD" and "gmake" or "make"
        end
    end,
    runCmd = function(_, cmd)
        print("cmd: ", cmd)
        os.execute(cmd)
    end,
    binaryName = function(_, name)
        if jit.os == "OSX" then
            return "lib" .. name .. ".dylib"
        else
            return "lib" .. name .. ".so"
        end
    end,
    --
    --
    prepareCJsonLibrary = function(self, dir_name, name)
        print("-- begin build cjson -- ")
        local c_sources = "lua_cjson.c strbuf.c fpconv.c"
        local clone_cmd =
            fmt("if [ ! -d '%s' ]; then git clone https://github.com/openresty/lua-cjson.git --depth 1; fi; ", dir_name)
        local make_cmd =
            fmt(
            "cd %s; if [ ! -f '%s.so' ]; then %s %s %s -o %s.so -I%s -L%s -l%s; fi;",
            dir_name,
            name,
            self.CC,
            self.CFLAGS,
            c_sources,
            name,
            self.INCPTH,
            self.LIBPATH,
            self.LIBNAME
        )
        local copy_cmd = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name))
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        self:runCmd(copy_cmd)
        print("-- end -- \n")
    end,
    prepareHyperparserLibrary = function(self, dir_name, name)
        print("-- begin build hyperparser -- ")
        local c_sources = "src/http_parser.c src/pull_style_api.c -Isrc"
        local clone_cmd =
            fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/hyperparser.git --depth 1; fi;", dir_name)
        local make_cmd =
            fmt(
            "cd %s; if [ ! -f '%s.so' ]; then %s %s %s -o %s.so ; fi; ",
            dir_name,
            name,
            self.CC,
            self.CFLAGS,
            c_sources,
            name
        )
        local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name, true))
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        self:runCmd(copy_binary)
        print("-- end -- \n")
    end,
    prepareDnsLibrary = function(self, dir_name, name)
        print("-- begin build mdns -- ")
        local clone_cmd =
            fmt(
            "if [ ! -d '%s' ]; then git clone https://github.com/lalawue/m_dnscnt.git --depth 1; cd %s; git submodule update --depth 1 --init --recursive; fi;",
            dir_name,
            dir_name
        )
        local git_update_cmd = "git pull origin master"
        local update_cmd =
            fmt(
            "if [ -d '%s' ]; then cd %s; make clean; %s; cd vendor/m_foundation/; %s; cd ../m_net; %s; fi;",
            dir_name,
            dir_name,
            git_update_cmd,
            git_update_cmd,
            git_update_cmd
        )
        local make_cmd = fmt("cd %s; if [ ! -f 'build/%s' ]; then %s; fi; ", dir_name, self:binaryName(name), self.MAKE)
        self:runCmd(update_cmd)
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        local binaries = {"mfoundation", "mnet", "mdns"}
        for _, v in ipairs(binaries) do
            local libname = self:binaryName(v)
            local copy_binary = fmt("cd %s; cp build/%s %s/%s", dir_name, libname, binary_dir, libname)
            self:runCmd(copy_binary)
        end
        print("-- end -- \n")
    end,
    prepareSprotoLibrary = function(self, dir_name, name)
        print("-- begin build sproto -- ")
        local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/sproto.git --depth 1; fi;", dir_name)
        local make_cmd =
            fmt(
            "cd %s; if [ ! -f '%s' ]; then %s LUA_JIT_INCLUDE_PATH=%s; fi; ",
            dir_name,
            self:binaryName(name),
            self.MAKE,
            self.INCPTH
        )
        local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name))
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        self:runCmd(copy_binary)
        print("-- end -- \n")
    end,
    prepareLpegLibrary = function(self, dir_name, name)
        print("-- begin build lpeg -- ")
        local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/lpeg.git --depth 1; fi;", dir_name)
        local make_cmd =
            fmt(
            "cd %s; if [ ! -f '%s' ]; then %s LUA_JIT_INCLUDE_PATH=%s; fi; ",
            dir_name,
            self:binaryName(name),
            self.MAKE,
            self.INCPTH
        )
        local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name))
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        self:runCmd(copy_binary)
        print("-- end -- \n")
    end,
    prepareLuaRBTreeLibrary = function(self, dir_name, name)
        print("-- begin build lrbtree -- ")
        local inc_dir = "-I" .. self.INCPTH
        local c_sources = "lrbtree.c rbtree.c"
        local c_compile = fmt("%s %s %s -l%s %s", self.CC, self.CFLAGS, inc_dir, self.LIBNAME, c_sources)
        local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/lrbtree.git --depth 1; fi;", dir_name)
        local make_cmd = fmt("cd %s; if [ ! -f '%s.so' ]; then %s -o %s.so ; fi; ", dir_name, name, c_compile, name)
        local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name, true))
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        self:runCmd(copy_binary)
        print("-- end -- \n")
    end,
    prepareLuaRedisClientLibrary = function(self, dir_name, name)
        print("-- begin build lua-resp -- ")
        local inc_dir = "-Isrc -I" .. self.INCPTH
        local c_sources = "src/lauxhlib.c src/resp.c "
        local c_compile = fmt("%s %s %s -l%s %s", self.CC, self.CFLAGS, inc_dir, self.LIBNAME, c_sources)
        local clone_cmd = fmt("if [ ! -d '%s' ]; then git clone https://github.com/lalawue/lua-resp.git --depth 1; fi;", dir_name)
        local make_cmd = fmt("cd %s; if [ ! -f '%s.so' ]; then %s -o %s.so ; fi; ", dir_name, name, c_compile, name)
        local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name, true))
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        self:runCmd(copy_binary)
        print("-- end -- \n")
    end,
    prepareLuaOpenSSLLibrary = function(self, dir_name, name)
        print("-- begin build lua-openssl -- ")
        local clone_cmd =
            fmt("if [ ! -d '%s' ]; then git clone --recurse https://github.com/zhaozg/lua-openssl.git --depth 1; fi;", dir_name)
        local make_cmd =
            fmt(
            "cd %s; if [ ! -f '%s.so' ]; then export PKG_CONFIG_PATH=%s; make; fi; ",
            dir_name,
            name,
            self.PKGPATH
        )
        local copy_binary = fmt("cd %s; cp %s.so %s/%s", dir_name, name, binary_dir, self:binaryName(name))
        self:runCmd(clone_cmd)
        self:runCmd(make_cmd)
        self:runCmd(copy_binary)
        print("-- end -- \n")
    end
}
Build.__index = Build

Build:setupToolchain()

print("Build with ENV (or you can export):")
print("MAKE: \t\t", Build.MAKE)
print("CC: \t\t", Build.CC)
print("CFLAGS: \t", Build.CFLAGS)
print("LUA_JIT_INCLUDE_PATH: ", Build.INCPTH)
print("LD_LIBRARY_PATH: ", Build.LIBPATH)
print("LUA_JIT_LIBRARY_NAME: ", Build.LIBNAME)
print("PKG_CONFIG_PATH: ", Build.PKGPATH)
print("\n--- prepare to build\n")
os.execute("sleep 3")

Build:prepareCJsonLibrary("lua-cjson", "cjson")
Build:prepareHyperparserLibrary("hyperparser", "hyperparser")
Build:prepareDnsLibrary("m_dnscnt", "mdns")
Build:prepareSprotoLibrary("sproto", "sproto")
Build:prepareLpegLibrary("lpeg", "lpeg")
Build:prepareLuaRBTreeLibrary("lrbtree", "lrbtree")
Build:prepareLuaRedisClientLibrary("lua-resp", "resp")
Build:prepareLuaOpenSSLLibrary("lua-openssl", "openssl")
