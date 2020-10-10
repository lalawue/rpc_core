--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local ffi = require("ffi")

ffi.cdef [[
/* -- Build query content
 * buf: buffer for store DNS query packet content, must have size == 1024 bytes
 * qid: DNS query id, make sure > 0
 * domain: '0' terminated string
 * --
 * return: 0 for error, or valid query_size > 0
 */
 int mdns_query_build(uint8_t *buf, unsigned short qid, const char *domain);

 /* -- fetch query id for later input query_size
  * buf: response buffer, must have size == 1024 byte
  * content_len: valid content length
  * --
  * return: 0 for error, or qid from response
  */
 int mdns_response_fetch_qid(const uint8_t *buf, int content_len);
 
 /* -- 
  * buf: response buffer, must have size == 1024 byte
  * content_len: valid content length
  * query_size: query_size for qid fetched before
  * domain: '0' terminated string for compare
  * out_ipv4: 4 byte buffer for output ipv4
  * --
  * return: 0 for error, 1 for ok
  */
 int mdns_response_parse(uint8_t *buf,
                         int content_len,
                         int query_size,
                         const char *domain,
                         uint8_t *out_ipv4);
]]

local DnsCore = ffi.load("mdns_utils")
local NetCore = require("base.ffi_mnet")
local UrlCore = require("middle.url")
local AvlTree = require("middle.ffi_avl")
local AppFramework = require("middle.app_framework")
local Log = require("middle.logger").newLogger("[DNS]", "debug")

local App = Class("DNS", AppFramework)

function App:initialize(app_name)
    -- 0.1 second
    self._app_timeout = 0.1
    self._svr_tbl = {}
    -- wait processing list as { qid, domain, query_size }
    self._qid_avl =
        AvlTree.new(
        function(a, b)
            return a.qid - b.qid
        end
    )
    -- result table domain to ipv4 string
    self._domain_tbl = {}
    -- wait response list
    self._wait_tbl = {}
    math.randomseed(os.time())
end

function App:loadBusiness(rpc_framework)
    -- init udp for query DNS
    self:_initUdpQueryChanns()

    -- init JSON service RPC
    rpc_framework.newService(
        AppEnv.Service.DNS_JSON,
        function(a, b, c)
            return self:_httpJsonServiceHandler(a, b, c)
        end
    )

    -- init Sproto service RPC
    rpc_framework.newService(
        AppEnv.Service.DNS_SPROTO,
        function(a, b, c)
            return self:_sprotoServiceHandler(a, b, c)
        end
    )
end

function App:startBusiness(rpc_framework)
    -- no coroutine code here
end

--
-- Internal
--

-- UDP DNS Query
function App:_initUdpQueryChanns()
    local dns_ipv4 = {
        "114.114.114.114",
        "8.8.8.8",
        "8.8.8.4"
    }
    for i = 1, #dns_ipv4, 1 do
        local udp_chann = NetCore.openChann("udp")
        udp_chann:setCallback(
            function(chann, event_name, _, _)
                if event_name == "event_recv" then
                    self:_processResponse(chann:recv())
                end
            end
        )
        udp_chann:connect(dns_ipv4[i], 53)
        self._svr_tbl[#self._svr_tbl + 1] = udp_chann
    end
end

-- SPROTO service interface
function App:_sprotoServiceHandler(proto_info, reqeust_object, rpc_response)
    if proto_info and proto_info.name == AppEnv.Service.DNS_SPROTO.name and type(reqeust_object.domain) == "string" then
        self:_processRequest(reqeust_object.domain, rpc_response)
        return true
    else
        Log:error("invalid sproto name %s", proto_info.name)
        return false
    end
end

-- HTTP JSON service interface
function App:_httpJsonServiceHandler(proto_info, reqeust_object, rpc_response)
    local url = UrlCore.parse(proto_info.url)
    if tostring(url.query):len() > 0 then
        for _, domain in pairs(url.query) do
            -- use whaterver key
            self:_processRequest(domain, rpc_response)
            break
        end
    elseif reqeust_object.domain then
        -- query with json
        self:_processRequest(reqeust_object.domain, rpc_response)
    else
        Log:error("invalid path or request_object !")
        return false
    end
    return true
end

local _copy = ffi.copy
local _fill = ffi.fill
local _string = ffi.string

local _buf = ffi.new("uint8_t[?]", 1024)
local _domain = ffi.new("uint8_t[?]", 256)
local _out_ipv4 = ffi.new("uint8_t[?]", 4)

function App:_processRequest(domain, rpc_response)
    if type(domain) ~= "string" then
        return
    end
    local ipv4 = self._domain_tbl[domain]
    if ipv4 then
        rpc_response:sendResponse({ipv4 = ipv4})
    else
        -- build UDP package
        local qid = math.random(65535)
        _fill(_domain, 256)
        _copy(_domain, domain)
        local query_size = DnsCore.mdns_query_build(_buf, qid, _domain)
        if query_size <= 0 then
            rpc_response:sendResponse({})
            return
        end
        local item = {qid = qid, domain = domain, query_size = query_size}
        self._qid_avl:insert(item)
        local data = _string(_buf, query_size)
        for _, chann in ipairs(self._svr_tbl) do
            chann:send(data)
        end
        -- add response to wait list
        if not self._wait_tbl[domain] then
            self._wait_tbl[domain] = {}
        end
        local tbl = self._wait_tbl[domain]
        tbl[#tbl + 1] = rpc_response
    end
end

function App:_processResponse(pkg_data)
    if pkg_data == nil then
        return
    end
    -- check response
    _copy(_buf, pkg_data, pkg_data:len())
    local qid = DnsCore.mdns_response_fetch_qid(_buf, pkg_data:len())
    local item = self._qid_avl:find({qid = qid})
    if not item then
        return
    end
    _fill(_domain, 256)
    _copy(_domain, item.domain)
    local ret = DnsCore.mdns_response_parse(_buf, pkg_data:len(), item.query_size, _domain, _out_ipv4)
    if ret <= 0 then
        Log:error(
            "failed parse item with ret:%d, qid:%d, query_size:%d, domain:%s",
            ret,
            qid,
            item.query_size,
            item.domain
        )
        self:_rpcResponse(item.domain, {})
        return
    end
    local out = _string(_out_ipv4, 4)
    local ipv4 = string.format("%d.%d.%d.%d", out:byte(1), out:byte(2), out:byte(3), out:byte(4))
    self._domain_tbl[item.domain] = ipv4
    -- process wait response
    self:_rpcResponse(item.domain, {ipv4 = ipv4})
    -- remove from wait processing list
    self._qid_avl:remove(item)
end

function App:_rpcResponse(domain, data)
    local tbl = self._wait_tbl[domain]
    if tbl then
        for _, rpc_response in ipairs(tbl) do
            rpc_response:sendResponse(data)
        end
        self._wait_tbl[domain] = nil
    end
end

return App
