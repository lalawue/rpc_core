#!/bin/sh
#
# luajit app launcher by lalawue

LUA_JIT=luajit

which_program() {
	which $1 > /dev/null
	if [ "$?" = "1" ]; then
		echo "\'$1\' NOT found, please install first !"
		exit 0
	fi
}

which_program $LUA_JIT

BINARIES_DIR=$PWD/binaries/

if [ ! -d $BINARIES_DIR/lib ]; then
    echo "Libraries not exist, please cd $BINARIES_DIR && ./install.sh first !"
    exit 0
fi

# LuaJIT path

# system library and Lua library path
export DYLD_LIBRARY_PATH=$BINARIES_DIR/lib/lua/5.1/
export LUA_CPATH=$BINARIES_DIR/lib/lua/5.1/?.so
export LUA_PATH="?.lua;middle/?.lua;$BINARIES_DIR/share/lua/5.1/?.lua"
export PATH=$PATH:$BINARIES_DIR/bin/

# luajit invoke
exec moocscript launcher.mooc $*
