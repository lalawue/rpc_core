
# About

m_rpc_framework was a LuaJIT base network bundle aim to easily build simple network apps. Like local DNS service provide RESTful JSON API, or a crawler rise requests to fetch gziped HTML pages.

Support MacOS/Linux/FreeBSD/Windows.


# Build supported libraries

first build supported binary libraries, under MacOS/Linux/FreeBSD, just

```
$ cd build
$ sh proj_build.sh
```
waits clone, build, then copy binaries finish, or you can download pre-compiled binaries in (release)[https://github.com/lalawue/m_rpc_framework/releases].


# Basic Examples

you can list supported apps just

```
$ ./run_app.sh
APP_ENV_CONFIG: not set, use config.app_env instead
supported apps:
        service_dns
        agent_test
```

in a terminal, setup DNS service with RESTfull JSON API

```
$ ./run_app.sh service_dns
APP_ENV_CONFIG: not set, use config.app_env instead
[App] 'class DnsAgent' load business
[RPC] rpc_framework start service 'dns_json' at '127.0.0.1:10053'
[RPC] rpc_framework start service 'dns_sproto' at '127.0.0.1:10054'
[App] 'class DnsAgent' start business coroutine
```

in another terminal, fetch page from www.baidu.com, print out HTTP headers

```
$ ./run_app.sh agent_test http://www.baidu.com
APP_ENV_CONFIG: not set, use config.app_env instead
[Test] Test init with agent_test
[App] 'class Test' load business
[App] 'class Test' start business coroutine
[Browser] -- openURL http://www.baidu.com
...
```


# Service Register

services name, ip, port, protocol, including extra APP_DIR, TMP_DIR, DATA_DIR are defined in config/app_env.lua.

you can use difference app_env.lua for difference app instance, just export APP_ENV_CONFIG=path_to_your_app_env.lua before run_app.sh.


# Setup a RESTful JSON API

to be continued...


# Fetch a gziped HTML page

to be continued...


# Use other protocol

you can define your own message serialization format, like apps.service_dns provide JSON and [Sproto](https://github.com/cloudwu/sproto) protocol service ports, defined in config/app_env.lua.


# Thanks

to be continued...

- lfs_ffi
- lua-ffi-zlib
- middleclass
- serpent
- hyperparser
- htmlparser
- sproto
- url
- LuaJIT
- lpeg
- cjson
