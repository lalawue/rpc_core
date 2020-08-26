
# About

rpc_framework was a LuaJIT base network bundle aim to easily build simple network apps. Like local DNS service provide RESTful JSON API, or a crawler rise requests to fetch gziped HTML pages.

Support MacOS/Linux/FreeBSD/Windows.


# Build dependent libraries

first build dependent libraries, under MacOS/Linux/FreeBSD, just

```js
$ export LUA_JIT_INCLUDE_PATH=/usr/local/include/luajit-2.1
$ cd build
$ sh proj_build.sh
```
waits clone, build, then copy binaries finish, or you can download pre-compiled binaries in [release](https://github.com/lalawue/rpc_framework/releases).

by the way, you can use your own build script as proj_build.lua, run as

```js
$ export LUA_JIT_INCLUDE_PATH=/usr/local/include/luajit-2.1
$ cd build
$ sh proj_build.sh YOUR_BUILD_SCRIPT.lua
```


# Launch App

you can list supported apps just

```js
$ ./run_app.sh
APP_ENV_CONFIG: not set, use config.app_env instead
I.[AppEnv] parse sproto spec config/app_rpc_spec.sproto
supported apps:
        service_dns
        agent_redis
        agent_test
```

in a terminal, setup DNS service with RESTfull JSON API

```js
$ ./run_app.sh service_dns
APP_ENV_CONFIG: not set, use config.app_env instead
[App] 'class DnsAgent' load business
[RPC] rpc_framework start service 'dns_json' at '127.0.0.1:10053'
[RPC] rpc_framework start service 'dns_sproto' at '127.0.0.1:10054'
[App] 'class DnsAgent' start business coroutine
```

in another terminal, fetch page from http://www.baidu.com, print out HTTP header

```js
$ ./run_app.sh agent_test http://www.baidu.com
APP_ENV_CONFIG: /PATH/TO/APP/ENV/DIR/app_env.lua
[Test] Test init with agent_test
[App] 'class Test' load business
[App] 'class Test' start business coroutine
[Browser] -- openURL http://www.baidu.com
[RPC] 'dns_json' connected: table: 0x09ec21c8
[RPC] 'dns_json' disconnect: table: 0x09ec21c8
[Browser] get 'www.baidu.com' ipv4 '14.215.177.38'
[Browser] try connect 14.215.177.38:80
[Browser] site connected: table: 0x09eb9600
[Browser] send http request: table: 0x09eb9600
[Browser] -- close URL: www.baidu.com
[Test] reqeust result: true
{
  header = {
    ["Cache-Control"] = "private, no-cache, no-store, proxy-revalidate, no-transform",
    Connection = "keep-alive",
    ["Content-Encoding"] = "gzip",
    ["Content-Type"] = "text/html",
    Date = "Sun, 09 Feb 2019 01:01:01 GMT",
    ["Last-Modified"] = "Mon, 23 Jan 2017 13:27:57 GMT",
    Pragma = "no-cache",
    Server = "bfe/1.0.8.18",
    ["Set-Cookie"] = "BDORZ=00001; max-age=86400; domain=.baidu.com; path=/",
    ["Transfer-Encoding"] = "chunked"
  } --[[table: 0x09e9a610]],
  readed_length = 1540,
  status_code = 200
} --[[table: 0x09e9a550]]
[Test] content length: 2381
```


# Service/App Register

services name, ip, port, protocol, including extra APP_DIR, TMP_DIR, DATA_DIR are defined in config/app_env.lua.

you can use difference app_env.lua for difference app instance, just export APP_ENV_CONFIG=/PATH/To/YOUR/app_env.lua before run_app.sh.

you can use another apps dir in AppEnv.Config.APP_DIR, outside rpc_framework/apps/.


# Setup a RESTful JSON API

first define HTTP JSON RESTful api in app_env.lua, likes below:

```lua
AppEnv.Service = {
   -- rpc_name = { name = "rpc_name", proto = 'AppEnv.Prototols', ipv4 = '127.0.0.1', port = 1024 }
   DNS_JSON = { name = "dns_json", proto = AppEnv.Prototols.HTTP_JSON, ipv4 = '127.0.0.1', port = 10053 },
   ...
}
```

then setup service callback with app framework in App:loadBusiness()

```lua
local UrlCore = require("middle.url")
local AppFramework = require("middle.app_framework")

local App = Class("ServiceClassName", AppFramework) -- create App instance

function App:initialize(...)
    -- get command line params in function params
end

function App:loadBusiness( rpc_framework )
    rpc_framework.newService(AppEnv.Service.DNS_JSON, function(proto_info, request_object, rpc_response)
        local url = UrlCore.parse(proto_info.url)
        table.dump( url ) -- dump URL info
        table.dump( request_object ) -- dump JSON objct
        local ret_table = { ["key"] = "value" } -- create return object 
        rpc_response:sendResponse( ret_table ) -- send response
    end)
end

function App:startBusiness( rpc_framework )
   -- service no coroutine code
end

function App:oneLoopInPoll()
    -- m_net one event loop callback
end

return App
```

more complicated service app is apps/service_dns, which provide HTTP_JSON and SPROTO interface, also created UDP
 port to query DNS service.


# Fetch a gziped HTML page

like apps/agent_test, create middle.http_browser instance, request gziped HTML pages.

```lua
local AppFramework = require("middle.app_framework")
local Browser = require("middle.http_browser")
local Log = require("middle.logger").newLogger("[AgentExample]", "info")

local AppExample = Class("AgentExample", AppFramework)

function AppExample:initialize(app_name, arg_1)
   self._app_name = app_name
   self._domain = arg_1
   if not arg_1 then
        Log:error("Usage: %s URL", app_name);
        os.exit(0)
   else
        Log:info("AppExample init with %s", app_name)
   end
end

function AppExample:loadBusiness(rpc_framework)
   -- as client, do nothing here
end

-- coroutine business
function AppExample:startBusiness(rpc_framework)
   local browser = Browser.newBrowser({ timeout = 30, inflate = true })
   local success, http_header, content = browser:openURL(self.m_domain)
   Log:info("reqeust result: %s", success)
   table.dump(http_header)
   Log:info("content length: %d", content:len())
      -- Log:info("content %s", content)
   os.exit(0)
end

return AppExample
```


# Use other protocol

you can define your own message serialization format, like apps/service_dns provide JSON and [Sproto](https://github.com/cloudwu/sproto) protocol service ports, defined in config/app_env.lua.


# Thanks

Thanks people provide libraries below:

- [LuaJIT](http://luajit.org/), a Just-In-Time Compiler for Lua by Mike Pall 
- [kikito/middleclass](https://github.com/kikito/middleclass), Object-orientation for Lua
- [sonoro1234/luafilesystem](https://github.com/sonoro1234/luafilesystem), Reimplement luafilesystem via LuaJIT FFI with unicode facilities
- [hamishforbes/lua-ffi-zlib](https://github.com/hamishforbes/lua-ffi-zlib)
- [pkulchenko/serpent](https://github.com/pkulchenko/serpent), Lua serializer and pretty printer
- [openssl/openssl](https://github.com/openssl/openssl), TLS/SSL and crypto library
- [armatys/hyperparser](https://github.com/armatys/hyperparser), Lua HTTP parser
- [openresty/lua-cjson](https://github.com/openresty/lua-cjson), Lua CJSON is a fast JSON encoding/parsing module for Lua
- [msva/lua-htmlparser](https://github.com/msva/lua-htmlparser), An HTML parser for lua
- [golgote/neturl](https://github.com/golgote/neturl), URL and Query string parser, builder, normalizer for Lua
- [cloudwu/sproto](https://github.com/cloudwu/sproto), Yet another protocol library like google protocol buffers , but simple and fast
- [lpeg](https://github.com/LuaDist/lpeg), Parsing Expression Grammars For Lua
- [mah0x211/lua-resp](https://github.com/mah0x211/lua-resp), RESP (REdis Serialization Protocol) parser for Lua
- [slembcke/debugger.lua](https://github.com/slembcke/debugger.lua), A simple, embedabble CLI debugger for Lua
- [ColonelThirtyTwo/lsqlite3-ffi](https://github.com/ColonelThirtyTwo/lsqlite3-ffi), Lua SQLite using LuaJIT's FFI library
- [daurnimator/fifo.lua](https://github.com/daurnimator/fifo.lua), Fifo library for Lua
- [Tieske/binaryheap.lua](https://github.com/Tieske/binaryheap.lua), Binary heap implementation in Lua
- [m_net](https://github.com/lalawue/m_net)
- [m_foundation](https://github.com/lalawue/m_foundation)
- [m_dnscnt](https://github.com/lalawue/m_dnscnt)
