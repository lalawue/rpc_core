
# About

rpc_core was a LuaJIT base network bundle aim to easily build simple network apps. Like local DNS service provide RESTful JSON API, or a crawler rise requests to fetch gziped HTML pages.

Support MacOS/Linux/FreeBSD.

Not support https, you can use [stunnel](https://www.stunnel.org/), [nginx](https://www.nginx.com/) or [openresty](https://openresty.org/) as HTTPS revers proxy.

currently only support [MoonCake](https://github.com/lalawue/mooncake), A Swift like programming language compiles to Lua, as its entry loader.


# Build dependent libraries

require [LuaJIT](https://luajit.org/) and [LuaRocks](https://luarocks.org/), please install it first.

```js
$ cd binaries
$ ./bootstrap.sh
```

here will install required rocks tree in binaries/ dir.

# Launch App

you can list supported apps just

```js
$ ./run_app.sh
APP_ENV_CONFIG: not set, use config.app_env instead
I.[AppEnv] parse sproto spec config/app_rpc_spec.sproto
supported apps:
        agent_objdb
        agent_redis
        agent_test
        service_dns
        service_objdb
```

in a terminal, setup DNS service with RESTfull JSON API

```js
$ ./run_app.sh service_dns
APP_ENV_CONFIG: not set, use config/app_env.mooc instead
I.[AppEnv] parse sproto spec config/rpc_spec.sproto
I.[App] 'DNS' load business
I.[RPC] rpc_core start service 'dns_json' at '127.0.0.1:10053'
I.[RPC] rpc_core start service 'dns_sproto' at '127.0.0.1:10054'
I.[App] 'DNS' start business coroutine
```

in another terminal, fetch page from http://www.baidu.com, print out HTTP header

```js
APP_ENV_CONFIG: not set, use config/app_env.mooc instead
I.[AppEnv] parse sproto spec config/rpc_spec.sproto
I.[Test] Test init with agent_test
I.[App] 'Test' load business
I.[App] 'Test' start business coroutine
I.[Test] -- newReqeust Service.DNS_JSON with URL http://www.baidu.com
I.[Test] get ip from host 'www.baidu.com'
I.[Test] DNS_JSON with path_args result true
I.[Test] DNS_JSON with body_args result true
I.[Test] LUA_SPROTO with path_args result true
I.[Test] LUA_SPROTO with body_args result true
I.[Test] open browser with http://www.baidu.com
I.[Browser] -- requestURL http://www.baidu.com
I.[Browser] get 'www.baidu.com' ipv4 '14.215.177.39' with port '80'
I.[Browser] try connect 14.215.177.39:80
I.[Browser] site connected: 0x0009c668
I.[Browser] send http request: 0x0009c668
I.[Browser] -- close URL: www.baidu.com
I.[Test] reqeust result: true
{
  header = {
    Bdpagetype = "1",
    Bdqid = "0xd0efc0fb0001527b",
    ["Cache-Control"] = "private",
    Connection = "keep-alive",
    ["Content-Encoding"] = "gzip",
    ["Content-Type"] = "text/html;charset=utf-8",
    Date = "Sun, 15 Aug 2021 02:47:14 GMT",
    Expires = "Sun, 15 Aug 2021 02:46:21 GMT",
    P3p = "CP=\" OTI DSP COR IVA OUR IND COM \"",
    Server = "BWS/1.1",
    ["Set-Cookie"] = "BAIDUID=C9142CA5B6094600C8D1EFA78A3C6D79:FG=1; expires=Thu, 31-Dec-37 23:55:55 GMT; max-age=2147483647; path=/; domain=.baidu.com",
    Traceid = "1628995634032181095415055464263592268411",
    ["Transfer-Encoding"] = "chunked",
    ["X-Frame-Options"] = "sameorigin",
    ["X-Ua-Compatible"] = "IE=Edge,chrome=1"
  } --[[table: 0x00509f38]],
  readed_length = 78154,
  status_code = 200
} --[[table: 0x000c8558]]
I.[Test] content length: 305023
```


# Service/App Register

services name, ip, port, protocol, including extra APP_DIR, TMP_DIR, DATA_DIR are defined in config/app_env.mooc.

you can use difference app_env.mooc for difference app instance, just export APP_ENV_CONFIG=/PATH/To/YOUR/app_env.mooc before run_app.sh.

you can use another apps dir in AppEnv.Config.APP_DIR, outside rpc_core/apps/.


# Setup a RESTful JSON API

first define HTTP JSON RESTful api in app_env.mooc, likes below:

```lua
AppEnv.Service = {
   --[[
      rpc_name = {
         name : "rpc_name",
         proto : 'AppEnv.Prototols',
         ipv4 : '127.0.0.1',
         port : 1024
      }
   ]]
   DNS_JSON : {
      name : "dns_json",
      proto : AppEnv.Prototols.HTTP_JSON,
      ipv4 : '127.0.0.1',
      port : 10053
   },
   ...
}
```

then setup service callback with app framework in App:loadBusiness()

```lua
import UrlCore from "middle.url"
import AppBase from "middle.app_framework"

-- create App instance
class MyService : AppBase {

   fn init(app_name, ...) {
      -- get command line params in function params
   }

   fn loadBusiness( rpc_core ) {
      rpc_core.newService(AppEnv.Service.DNS_JSON, { proto_info, request_object, rpc_response in
         url = UrlCore.parse(proto_info.url)
         table.dump( url ) -- dump URL info
         table.dump( request_object ) -- dump JSON objct
         ret_table = { ["key"] : "value" } -- create return object 
         rpc_response:sendResponse( ret_table ) -- send response
      }
   }

   fn startBusiness( rpc_core ) {
      -- service no coroutine code
   }

   fn oneLoopInPoll() {
      -- m_net one event loop callback
   }
}

return MyService
```

more complicated service app is apps/service_dns, which provide HTTP_JSON and SPROTO interface, also created UDP
 port to query DNS service.


# Fetch a gziped HTML page

like apps/agent_test, create middle.http_browser instance, request gziped HTML pages.

```lua
import AppBase from "middle.app_framework"
import Browser from "middle.http_browser"
Log = require("middle.logger")("[AgentExample]", "info")

class AppExample : AppBase {

   fn init(app_name, arg_1) {
      self._app_name = app_name
      self._domain = arg_1
      if not arg_1 {
         Log:error("Usage: %s URL", app_name);
         os.exit(0)
      } else {
         Log:info("AppExample init with %s", app_name)
      }
   }

   fn loadBusiness(rpc_core) {
      -- as client, do nothing here
   }

   -- coroutine business
   fn startBusiness(rpc_core) {
      browser = Browser({ timeout: 30, inflate: true })
      success, http_header, content = browser:openURL(self.m_domain)
      Log:info("reqeust result: %s", success)
      table.dump(http_header)
      Log:info("content length: %d", content:len())
      -- Log:info("content %s", content)
      os.exit(0)
   }
}

return AppExample
```


# Use other protocol

you can define your own message serialization format, like apps/service_dns provide JSON and [Sproto](https://github.com/cloudwu/sproto) protocol service ports, defined in config/app_env.mooc.

or apps/service_objdb using RESP (Redis Protocol specification 2) for object storage with [ffi_bitcask.lua](https://github.com/lalawue/ffi_bitcask.lua) as its backend.


# Thanks

Thanks people provide libraries below:

- [LuaJIT](http://luajit.org/), a Just-In-Time Compiler for Lua by Mike Pall 
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
- [cloudwu/lua-serialize](https://github.com/cloudwu/lua-serialize), Serialize lua objects into a binary block
- [TiagoDanin/htmlEntities-for-lua](https://github.com/TiagoDanin/htmlEntities-for-lua)
- [m_net](https://github.com/lalawue/m_net)
- [m_dnsutils](https://github.com/lalawue/m_dnsutils)
- [ffi_bitcask.lua](https://github.com/lalawue/ffi_bitcask.lua)
- [mooncake](https://github.com/lalawue/mooncake)
