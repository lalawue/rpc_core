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
    self._app_name = app_name
    self._store_file_name = arg_store_file_name
    self._url = arg_url
    if not self._url then
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
    local url_info = UrlCore.parse(self._url)

    if not url_info then
        Log:error("fail to parse url '%s'", self._url)
        os.exit(0)
    end

    if type(url_info.scheme) ~= "string" or (url_info.scheme ~= "http" and url_info.scheme ~= "https") then
        Log:error("invalid scheme %s, try 'https://www.baidu.com'", url_info.scheme)
        os.exit(0)
    end

    self._url_info = url_info
    Log:info("-- newReqeust Service.DNS_JSON with URL %s", self._url)

    if type(url_info.host) ~= "string" then
        Log:error("invalid host")
    end

    -- only query domain DNS
    if url_info.host:find("%d-%.%d-%.%d-%.%d+") then
        Log:info("open ipv4 with host: %s", url_info.host)
    else
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
    end

    Log:info("open browser with %s", self._url)
    local browser = Browser.newBrowser()
    local success, http_header, content = browser:requestURL(self._url, {timeout = 30, inflate = true})
    Log:info("reqeust result: %s", success)
    if success then
        -- Log:info("content %s", content)
        table.dump(http_header)
        Log:info("content length: %d", content:len())
        if type(self._store_file_name) == "string" and self._store_file_name:len() > 0 then
            FileManager.saveFile(self._store_file_name, content)
        end
    else
        Log:info("failed to get result")
    end
    os.exit(0)
end

return Test
