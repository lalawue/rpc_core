#!/bin/sh
#
# luajit app launcher by lalawue

BINARIES_DIR=$PWD/binaries/$(uname)
if [ ! -d $BINARIES_DIR ]; then
    echo "binaries dir not exist, please cd build/ && ./proj_build.sh first !"
    exit 0
else
    echo $BINARIES_DIR
fi

# export system library and Lua library path
if [ "$(uname)" = "Darwin" ]; then
    export DYLD_LIBRARY_PATH=$BINARIES_DIR
    export LUA_CPATH=$BINARIES_DIR/lib?.dylib
else
    export LD_LIBRARY_PATH=$BINARIES_DIR
    export LUA_CPATH=$BINARIES_DIR/lib?.so
fi

# export LuaJIT path
export LUA_PATH="?.lua;middle/?.lua;"

# luajit invoke
luajit app_launcher.lua $*
