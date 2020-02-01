@echo off
Rem
Rem luajit app launcher by lalawue

Rem export system library and Lua library path
set PATH=%CD%\binaries\WindowsNT

Rem export LuaJIT path
set LUA_PATH=?.lua;middle\?.lua;

Rem luajit invoke
luajit.exe app_launcher.lua %*
