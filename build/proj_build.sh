#!/bin/sh
#
# project library builder

GIT_CMD=git
LUA_JIT=luajit
LUA_ROCKS=luarocks

which_program()
{
    which $1 > /dev/null
    if [ "$?" == "1" ]; then
        echo "\'$1\' NOT found, failed to build binary modules, exit build !"    
        exit 0
    fi    
}

which_program $GIT_CMD
which_program $LUA_JIT
which_program $LUA_ROCKS

if [ "$(basename $PWD)" = "build" ]; then
    export MACOSX_DEPLOYMENT_TARGET=10.14
    mkdir -p "../binaries/$(uname)"
    $LUA_JIT proj_build.lua $PWD $(uname)
else
    echo "Invalid directory, please run command in directory 'build'"
    exit 0
fi



