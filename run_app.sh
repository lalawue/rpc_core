#!/bin/sh
#
# luajit app launcher by lalawue

LOCAL_DIR=$PWD/binaries/Local
BINARIES_DIR=$PWD/binaries/$(uname)

if [ "$#" = "0" ]; then
    echo "Usage: $0 APP_NAME"
    exit 0
fi

if [ ! -d $BINARIES_DIR ]; then
    echo "binaries dir not exist, please cd build/ && ./proj_build.sh first !"
    exit 0
fi

# LuaJIT path
LUA_PATH="?.lua;middle/?.lua;"

# system library and Lua library path
if [ "$(uname)" = "Darwin" ]; then
    LIB_PATH=$BINARIES_DIR:$LOCAL_DIR/lib
    LUA_CPATH=$BINARIES_DIR/lib?.dylib

    # luajit invoke
    env DYLD_LIBRARY_PATH=$LIB_PATH LUA_CPATH=$LUA_CPATH LUA_PATH=$LUA_PATH luajit app_launcher.lua $*    
else
    LIB_PATH=$BINARIES_DIR:$LOCAL_DIR/lib:/usr/lib:/usr/local/lib
    LUA_CPATH=$BINARIES_DIR/lib?.so

    # luajit invoke
    env LD_LIBRARY_PATH=$LIB_PATH LUA_CPATH=$LUA_CPATH LUA_PATH=$LUA_PATH luajit app_launcher.lua $*    
fi
