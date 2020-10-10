--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local TcpRaw = require("middle.tcp_stream.tcp_raw")
local TcpSSL = require("middle.tcp_stream.tcp_ssl")
local UrlCore = require("middle.url")
local HttpParser = require("middle.ffi_hyperparser")
local RpcFramework = require("middle.rpc_framework")
local FileManager = require("middle.file_manager")
local Log = require("middle.logger").newLogger("[Browser]", "info")

local Browser = {}
Browser.__index = Browser

-- create browser in coroutine
function Browser.newBrowser()
    if coroutine.running() == nil then
        Log:error("browser should create from coroutine")
        return nil
    end
    local brw = {
        _chann = nil, -- one tcp chann
        _hp = nil, -- hyperparser
        _url_info = nil -- path, host, port
    }
    return setmetatable(brw, Browser)
end

-- act like curl, accept encoding gzip
local function _buildHttpRequest(method, url_info, option, data)
    if type(method) ~= "string" then
        Log:error("method should be 'GET' or 'POST'")
        return nil
    end
    local sub_path = "/"
    if url_info.path and url_info.path:len() > 0 then
        sub_path = url_info.path
    end
    if type(url_info.query) == "table" then
        local query = UrlCore.buildQuery(url_info.query)
        if query and query:len() > 0 then
            sub_path = sub_path .. "?" .. query
        end
    end
    local tbl = {}
    tbl[#tbl + 1] = string.format("%s %s HTTP/1.1", method, sub_path)
    if url_info.host then
        tbl[#tbl + 1] = "Host: " .. url_info.host
    end
    tbl[#tbl + 1] = "User-Agent: mrpc/v20200804"
    if option and option.inflate then
        tbl[#tbl + 1] = "Accept-Encoding: gzip"
    end
    if option and type(option.header) == "table" then
        for k, v in pairs(option.header) do
            tbl[#tbl + 1] = k .. ": " .. v
        end
    end
    if data then
        tbl[#tbl + 1] = "Content-Length: " .. data:len()
    end
    tbl[#tbl + 1] = "\r\n"
    if data then
        tbl[#tbl + 1] = data
    end
    return table.concat(tbl, "\r\n")
end

local function _processRecvData(brw, data)
    local ret, state, http_tbl = brw._hp:process(data)
    if ret < 0 then
        return ret
    end
    return ret, state, http_tbl
end

-- return empty when gzip and not finish
local function _constructContent(http_tbl, option, is_finish)
    if http_tbl.contents == nil then
        return ""
    end
    local output_content = ""
    local input_content = table.concat(http_tbl.contents)
    local encoding_desc = http_tbl.header["Content-Encoding"]
    local is_gzip = encoding_desc == "gzip"
    if is_gzip and is_finish then
        output_content = FileManager.inflate(input_content)
    elseif not is_gzip then
        output_content = input_content
    end
    if output_content:len() > 0 then
        http_tbl.contents = nil
    end
    return output_content
end

--[[
    request HTTP/HTTPS URL
    option = {
        inflate = false, -- default
        header = header, -- table
        recv_cb = function(header_tbl, data_string) end, -- for receiving data
    }
    return header_tbl, data_string (if no recv_cb function set)
]]
function Browser:requestURL(site_url, option)
    if type(site_url) ~= "string" and not coroutine.running() then
        Log:error("please requestURL from coroutine")
        return false
    end

    if self._chann then
        Log:error("stream was opened, close it before open again")
        return false
    end

    local url_info = UrlCore.parse(site_url)
    if not url_info then
        Log:error("fail to parse url '%s'", site_url)
        return false
    end

    if type(url_info.scheme) ~= "string" then
        Log:error("scheme was empty, invalid url")
        return false
    end

    if url_info.scheme ~= "http" and url_info.scheme ~= "https" then
        Log:error("invalid scheme")
        return false
    elseif url_info.scheme == "https" and not TcpSSL then
        Log:error("SSL module not ready, can not support 'HTTPS'")
        return false
    end

    if type(url_info.host) ~= "string" then
        Log:error("invalid host")
        return false
    end

    self._url_info = url_info
    Log:info("-- requestURL %s", site_url)

    local ipv4 = nil
    local port = nil
    local ipv4_pattern = "%d-%.%d-%.%d-%.%d+"
    if url_info.host:find(ipv4_pattern) then
        ipv4 = url_info.host:match("(" .. ipv4_pattern .. ")")
        port = url_info.port
    else
        local timeout_second = option and option.timeout or AppEnv.Config.RPC_TIMEOUT
        local path_args = {domain = url_info.host} -- use HTTP path query string, whatever key

        local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, {timeout = timeout_second}, path_args)
        if not success or table.isempty(datas) then
            Log:error("failed to dns '%s'", url_info.host)
            return false
        end
        datas = #datas > 0 and datas[1] or datas
        ipv4 = datas["ipv4"]
        port = url_info.port
    end

    if url_info.scheme == "http" then
        self._chann = TcpRaw.openChann()
        port = port and tonumber(port) or 80
    else
        self._chann = TcpSSL.openChann()
        port = port and tonumber(port) or 443
    end
    url_info = nil -- reset nil
    Log:info("get '%s' ipv4 '%s' with port '%d'", self._url_info.host, ipv4, port)

    local brw = self
    local co = coroutine.running()
    local data_tbl = {}
    local recv_cb = option and option.recv_cb or function(header_tbl, data_string)
            if data_string then
                data_tbl[#data_tbl + 1] = data_string
            end
        end
    local callback = function(chann, event_name, _, _)
        if event_name == "event_connected" then
            brw._hp = brw._hp or HttpParser.createParser("RESPONSE")
            Log:info("site connected: %s", chann)
            local data = _buildHttpRequest("GET", brw._url_info, option)
            chann:send(data)
            Log:info("send http request: %s", chann)
        elseif event_name == "event_recv" then
            local ret, state, http_tbl = _processRecvData(brw, chann:recv())
            if ret < 0 then
                Log:info("fail to process recv data")
                brw:closeURL()
                brw = nil
                recv_cb(nil, nil)
                coroutine.resume(co, false)
            elseif state == HttpParser.STATE_BODY_CONTINUE and http_tbl then
                local content = _constructContent(http_tbl, option, false)
                if content:len() > 0 then
                    recv_cb(http_tbl, content)
                end
            elseif state == HttpParser.STATE_BODY_FINISH and http_tbl then
                -- FIXME: consider status code 3XX
                -- FIXME: support cookies
                -- FIXME: support keep-alive
                brw:closeURL()
                brw = nil
                local content = _constructContent(http_tbl, option, true)
                recv_cb(http_tbl, content)
                recv_cb(http_tbl, nil)
                coroutine.resume(co, true, http_tbl, table.concat(data_tbl))
            end
        elseif event_name == "event_disconnect" or event_name == "event_timer" then
            brw:closeURL()
            brw = nil
            recv_cb(nil, nil)
            coroutine.resume(co, false)
        end
    end
    self._chann:setCallback(callback)
    self._chann:connectAddr(ipv4, port)
    if option and option.timeout then
        self._chann:setEventTimer(option.timeout)
    end
    RpcFramework.setLoopEvent(
        tostring(self),
        function()
            return self:onLoopEvent()
        end,
        nil
    )
    Log:info("try connect %s:%d", ipv4, port)
    return coroutine.yield()
end

-- return true/false, http header, data, one at a time
function Browser:postURL(site_url, data)
    if type(site_url) ~= "string" or not coroutine.running() then
        Log:error("please postURL from coroutine")
        return false
    end
    return false
end

function Browser:closeURL()
    Log:info("-- close URL: %s", self._url_info and self._url_info.host or "empty URL !")
    if self._chann then
        self._chann:setEventTimer(0)
        self._chann:closeChann()
        self._chann = nil
    end
    self._hp:reset()
    self._url_info = nil
end

function Browser:onLoopEvent()
    if self._chann.onLoopEvent then
        return self._chann:onLoopEvent()
    end
    return true
end

return Browser
