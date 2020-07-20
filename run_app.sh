#!/bin/sh
#
# luajit app launcher by lalawue

LOCAL_DIR=$PWD/binaries/Local
BINARIES_DIR=$PWD/binaries/$(uname)

if [ ! -d $BINARIES_DIR ]; then
    echo "binaries dir not exist, please cd build/ && ./proj_build.sh first !"
    exit 0
fi

# LuaJIT path
export LUA_PATH="?.lua;middle/?.lua;"

# system library and Lua library path
if [ "$(uname)" = "Darwin" ]; then
    export DYLD_LIBRARY_PATH=$BINARIES_DIR:$LOCAL_DIR/lib
    export LUA_CPATH=$BINARIES_DIR/lib?.dylib
else
    export LD_LIBRARY_PATH=$BINARIES_DIR:$LOCAL_DIR/lib:/usr/lib:/usr/local/lib
    export LUA_CPATH=$BINARIES_DIR/lib?.so
fi

# luajit invoke
exec luajit app_launcher.lua $*
