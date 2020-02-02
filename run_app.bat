@echo off
Rem
Rem luajit app launcher by lalawue

if exist %CD%\binaries\WindowsNT (
    Rem export system library and Lua library path
    set PATH=%CD%\binaries\WindowsNT

    Rem export LuaJIT path
    set LUA_PATH=?.lua;middle\?.lua;

    Rem luajit invoke
    luajit.exe app_launcher.lua %*
) else (
    echo [ERROR] binaries dir not exist, please build required binaries first !
)
