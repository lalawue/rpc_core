--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local ffi = require("ffi")

ffi.cdef [[
typedef enum {
   MDNS_STATE_INVALID = 0,
   MDNS_STATE_INPROGRESS,
   MDNS_STATE_SUCCESS,
} mdns_state_t;

typedef struct {
   unsigned char ipv4[4];       /* ip */
   mdns_state_t state;          /* pull-style api */
   char *err_msg;               /* error message */
} mdns_result_t;

// pull-style api mnet_init(1), input udp chann_t array with count
int mdns_init(void *udp_chann_array, int count);
void mdns_fini(void);

// recv chann_msg_t data, , return 1 for got ip
int mdns_store(void *chann_msg_t);

// send data to udp   
mdns_result_t* mdns_query(const char *domain, int domain_len);

// convert ipv4[4] to string ip max 16 bytes
const char* mdns_addr(unsigned char *ipv4);

// clean oudated ip   
void mdns_cleanup(int timeout_ms);
]]

local DnsCore = ffi.load("mdns")
local NetCore = require("base.ffi_mnet")
local UrlCore = require("middle.url")
local AppFramework = require("middle.app_framework")
local Log = require("middle.logger").newLogger("[DNS]", "debug")

--
-- App
--

local App = Class("DnsAgent", AppFramework)

function App:initialize()
    if not self.m_has_init then
        self.m_has_init = true
        self.m_wait_list = setmetatable({}, {__mode = "v"})
    end
end

local _result = ffi.new("mdns_result_t *")

local function _queryDomainFromDnsCore(domain)
    local dn = ffi.new("char[?]", domain:len() + 1)
    ffi.copy(dn, domain, domain:len())
    _result = DnsCore.mdns_query(dn, domain:len())
    if _result.state == DnsCore.MDNS_STATE_INVALID then
        return false, _result.err_msg
    elseif _result.state == DnsCore.MDNS_STATE_INPROGRESS then
        return false, nil
    else
        local ipv4 = ffi.string(DnsCore.mdns_addr(_result.ipv4))
        return true, ipv4
    end
end

-- UDP DNS Query
local function _initUdpQueryInterface()
    local dns_ipv4 = {
        "8.8.8.8",
        "8.8.8.4"
    }
    local c_udp_channs = ffi.new("chann_t*[?]", #dns_ipv4)
    for i = 1, 2 do
        local udp_chann = NetCore.openChann("udp")
        udp_chann:connect(dns_ipv4[i], 53)
        udp_chann:setCallback(
            function(_, event_name, _, c_msg)
                if event_name == "event_recv" then
                    DnsCore.mdns_store(c_msg)
                end
            end
        )
        c_udp_channs[i - 1] = udp_chann.m_chann
    end
    -- set C UDP chann to DnsCore
    DnsCore.mdns_init(c_udp_channs, #dns_ipv4)
end

local function _updateWaitingList(self, domain, rpc_response)
    local success, ip = _queryDomainFromDnsCore(domain)
    if success and ip then
        rpc_response:sendResponse({ipv4 = ip})
    else
        self.m_wait_list[domain] = rpc_response
    end
end

-- HTTP JSON service interface
local function _httpJsonServiceHandler(self, proto_info, reqeust_object, rpc_response)
    local url = UrlCore.parse(proto_info.url)
    if tostring(url.query):len() > 0 then
        for _, domain in pairs(url.query) do
            -- use whaterver key
            _updateWaitingList(self, domain, rpc_response)
            break
        end
    elseif reqeust_object["domain"] then
        -- query with json
        _updateWaitingList(self, reqeust_object.domain, rpc_response)
    else
        Log:error("invalid path or request_object !")
        return false
    end
    return true
end

-- SPROTO service interface
local function _sprotoServiceHandler(self, proto_info, reqeust_object, rpc_response)
    if proto_info and proto_info.name == AppEnv.Service.DNS_SPROTO.name and type(reqeust_object.domain) == "string" then
        _updateWaitingList(self, reqeust_object.domain, rpc_response)
        return true
    else
        Log:error("invalid sproto name %s", proto_info.name)
        return false
    end
end

function App:loadBusiness(rpc_framework)
    -- init udp for query DNS
    _initUdpQueryInterface()

    -- init JSON service RPC
    rpc_framework.newService(
        AppEnv.Service.DNS_JSON,
        function(a, b, c)
            return _httpJsonServiceHandler(self, a, b, c)
        end
    )

    -- init Sproto service RPC
    rpc_framework.newService(
        AppEnv.Service.DNS_SPROTO,
        function(a, b, c)
            return _sprotoServiceHandler(self, a, b, c)
        end
    )
end

function App:startBusiness(rpc_framework)
    -- no coroutine code here
end

-- one loop in poll
function App:oneLoopInPoll()
    for domain, response in pairs(self.m_wait_list) do
        local success, ip = _queryDomainFromDnsCore(domain)
        if success and ip then
            response:sendResponse({ipv4 = ip})
            self.m_wait_list[domain] = nil
        end
    end
end

return App
