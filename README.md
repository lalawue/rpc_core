
# About

m_rpc_framework was a LuaJIT base network bundle aim to easily build simple network apps. Like local DNS service provide RESTful JSON API, or a crawler rise requests to fetch gziped HTML pages.

Support MacOS/Linux/Windows, FreeBSD not tested.


# Build supported libraries

first build supported binary libraries, under MacOS/Linux, just

```
$ cd build
$ ./proj_build.sh
```
waits clone, build, then copy binaries finish.


# Examples

in a terminal, setup DNS service with RESTfull JSON API

```
$ ./run_app.sh service_dns
```

in another terminal, open a URL, first get IP from local DNS service

```
$ ./run_app.sh agent_test http://www.baidu.com
```


# Setup a RESTful JSON API

to be continued...


# Fetch a gziped HTML page

to be continued...


# Use other protocol

you can define your own message serialization format, like apps.service_dns provide JSON and [Sproto](https://github.com/cloudwu/sproto) protocol service ports, 


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
