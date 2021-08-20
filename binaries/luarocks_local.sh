#!/bin/sh
#
# project library builder

LUA_JIT=luajit
LUA_ROCKS=luarocks

which_program() {
	which $1 > /dev/null
	if [ "$?" = "1" ]; then
		echo "\'$1\' NOT found, please install first !"
		exit 0
	fi
}

which_program $LUA_JIT
which_program $LUA_ROCKS

if [ -z $1 ]; then
	echo "luarocks_local.sh was alias for \"$LUA_ROCKS --tree . $*\""
	exit 0
fi

$LUA_ROCKS --tree $PWD $*
