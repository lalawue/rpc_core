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

print_var()
{
    echo "$1LUAJIT_INC_DIR=$LUAJIT_INC_DIR"
    echo "$1LUAJIT_LIB_DIR=$LUAJIT_LIB_DIR"
    echo "$1LUAJIT_LIB_NAME=$LUAJIT_LIB_NAME"
    echo "$1PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
}

if [ ! "$LUAJIT_INC_DIR" ] || [ ! "$LUAJIT_LIB_DIR" ] || [ ! "$LUAJIT_LIB_NAME" ] || [ ! "$PKG_CONFIG_PATH" ]; then
    echo "First export variable below:"
    print_var "export "
    echo "try install openssl 1.1.1_ from apt-get or brew install"
    exit 0
fi

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
