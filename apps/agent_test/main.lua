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
local FileManager = require("middle.file_manager")

local Test = Class("Test", AppFramework)

function Test:initialize(app_name, arg_url, arg_store_file_name)
    self.m_app_name = app_name
    self.m_store_file_name = arg_store_file_name
    self.m_url = arg_url
    if not self.m_url then
        Log:error("Usage: %s URL [STORE_FILE_NAME]", app_name)
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
    local url_info = UrlCore.parse(self.m_url)

    if not url_info then
        Log:error("fail to parse url '%s'", self.m_url)
        os.exit(0)
    end

    if type(url_info.scheme) ~= "string" or (url_info.scheme ~= "http" and url_info.scheme ~= "https") then
        Log:error("invalid scheme %s, try 'https://www.baidu.com'", url_info.scheme)
        os.exit(0)
    end

    self.m_url_info = url_info
    Log:info("-- newReqeust Service.DNS_JSON with URL %s", self.m_url)

    Log:info("get ip from host '%s'", url_info.host)
    local timeout_second = AppEnv.Config.RPC_TIMEOUT
    local path_args = {["domain"] = url_info.host} -- use HTTP path query string, whatever key

    local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, {timeout = timeout_second}, path_args)
    Log:info("DNS_JSON with path_args result %s", success)

    success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, {timeout = timeout_second}, nil, path_args)
    Log:info("DNS_JSON with body_args result %s", success)

    success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_SPROTO, {timeout = timeout_second}, path_args)
    Log:info("LUA_SPROTO with path_args result %s", success)

    success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_SPROTO, {timeout = timeout_second}, nil, path_args)
    Log:info("LUA_SPROTO with body_args result %s", success)

    if not success then
        Log:error("failed to get ip from '%s'", url_info.host)
        os.exit(0)
    end

    Log:info("open browser with %s", self.m_url)
    local browser = Browser.newBrowser({timeout = 30, inflate = true})
    local success, http_header, content = browser:openURL(self.m_url)
    Log:info("reqeust result: %s", success)
    if success then
        -- Log:info("content %s", content)
        table.dump(http_header)
        Log:info("content length: %d", content:len())
        if type(self.m_store_file_name) == "string" and self.m_store_file_name:len() > 0 then
            FileManager.saveFilePath(self.m_store_file_name, content)
        end
    else
        Log:info("failed to get result")
    end
    os.exit(0)
end

return Test
