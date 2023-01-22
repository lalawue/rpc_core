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

INSTALL="$LUA_ROCKS --tree . install"
echo $INSTALL

$INSTALL specs/mnet-cincau-1.rockspec OPENSSL_INCDIR=/usr/include/
$INSTALL ffi-hyperparser
$INSTALL mooncake
$INSTALL lua-resp
$INSTALL lua-serialize
$INSTALL sproto
$INSTALL lua-cjson
$INSTALL serpent
$INSTALL sql-orm
$INSTALL date

BINARIES_DIR=lib/lua/5.1/

if [ "$(uname)" = "Darwin" ]; then
	echo cd lib/lua/5.1
	cd lib/lua/5.1
	for f in *.so; do
		e=$(echo $f | cut -d. -f1)
		echo ln -sf $f lib$e.dylib
		ln -sf $f lib$e.dylib
	done
elif [ "$(uname)" = "Linux" ]; then
	echo cd lib/lua/5.1
	cd lib/lua/5.1
	for f in *.so; do
		e=$(echo $f | cut -d. -f1)
		echo ln -sf $f lib$e.so
		ln -sf $f lib$e.so
	done

fi
