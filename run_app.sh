#!/bin/sh
#
# luajit app launcher by lalawue

BIN_DIR=$PWD/binaries/bin/
BINARIES_DIR=$PWD/binaries/$(uname)

if [ ! -d $BINARIES_DIR ]; then
    echo "binaries dir not exist, please cd build/ && ./proj_build.sh first !"
    exit 0
fi

# LuaJIT path
export LUA_PATH="?.lua;middle/?.lua;"

# system library and Lua library path
if [ "$(uname)" = "Darwin" ]; then
    export DYLD_LIBRARY_PATH=$BINARIES_DIR
    export LUA_CPATH=$BINARIES_DIR/lib?.dylib
    export PATH=$PATH:$BIN_DIR
else
    export LD_LIBRARY_PATH=$BINARIES_DIR:/usr/lib:/usr/local/lib
    export LUA_CPATH=$BINARIES_DIR/lib?.so
    export PATH=$PATH:$BIN_DIR
fi

# luajit invoke
exec moocscript app_launcher.mooc $*
