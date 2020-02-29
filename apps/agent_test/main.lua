--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local AppFramework = require("middle.app_framework")
local UrlCore = require("middle.url")
local RpcFramework = require("middle.rpc_framework")
local Browser = require("middle.http_browser")
local Log = require("middle.logger").newLogger("[Test]", "info")

local Test = Class("Test", AppFramework)

function Test:initialize(app_name, arg_url, arg_2)
    self.m_app_name = app_name
    self.m_url = arg_url
    if not self.m_url then
        Log:error("Usage: %s URL", app_name)
        os.exit(0)
    else
        Log:info("Test init with %s", app_name)
    end
end

function Test:loadBusiness(rpc_framework)
    -- as client, do nothing here
end

function Test:startBusiness(rpc_framework)
    -- test HTTP_JSON and LUA_SPROTO
    local url = UrlCore.parse(self.m_url)
    if not url then
        Log:error("fail to parse url '%s'", self.m_url)
        return false
    end
    self.m_url_info = url
    Log:info("-- newReqeust Service.DNS_JSON with URL %s", self.m_url)

    local timeout_second = AppEnv.Config.BROWSER_TIMEOUT
    local path_args = {["domain"] = url.host} -- use HTTP path query string, whatever key

    local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, {timeout = timeout_second}, path_args)
    Log:info("DNS_JSON with path_args result %s", success)

    success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, {timeout = timeout_second}, nil, path_args)
    Log:info("DNS_JSON with body_args result %s", success)

    success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_SPROTO, {timeout = timeout_second}, path_args)
    Log:info("LUA_SPROTO with path_args result %s", success)

    success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_SPROTO, {timeout = timeout_second}, nil, path_args)
    Log:info("LUA_SPROTO with body_args result %s", success)

    Log:info("open browser with %s", self.m_url)
    local browser = Browser.newBrowser({timeout = 30, inflate = true})
    local success, http_header, content = browser:openURL(self.m_url)
    Log:info("reqeust result: %s", success)
    table.dump(http_header)
    Log:info("content length: %d", content:len())
    -- Log:info("content %s", content)
    os.exit(0)
end

return Test
