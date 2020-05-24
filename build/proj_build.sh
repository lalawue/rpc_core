#!/bin/sh
#
# project library builder

GIT_CMD=git
LUA_JIT=luajit

which_program()
{
    which $1 > /dev/null
    if [ "$?" = "1" ]; then
        echo "\'$1\' NOT found, failed to build binary modules, exit build !"    
        exit 0
    fi    
}

which_program $GIT_CMD
which_program $LUA_JIT

if [ "$(basename $PWD)" = "build" ]; then
    export MACOSX_DEPLOYMENT_TARGET=10.14
    mkdir -p "../binaries/$(uname)"
    if [ -n "$1" ]; then
        echo "use privide build script $1"
        sleep 1
        $LUA_JIT $1 $PWD $(uname)
    else
        $LUA_JIT proj_build.lua $PWD $(uname)
    fi
else
    echo "Invalid directory, please run command in directory 'build'"
    exit 0
fi
