#!/bin/sh
#
# luajit app launcher by lalawue

# export system library and Lua library path
if [ "$(uname)" = "Darwin" ]; then
    export DYLD_LIBRARY_PATH=$PWD/binaries/$(uname)
    export LUA_CPATH=$PWD/binaries/$(uname)/lib?.dylib
else
    export LD_LIBRARY_PATH=$PWD/binaries/$(uname)
    export LUA_CPATH=$PWD/binaries/$(uname)/lib?.so
fi

# export LuaJIT path
export LUA_PATH="?.lua;middle/?.lua;"

# luajit invoke
luajit app_launcher.lua $*
