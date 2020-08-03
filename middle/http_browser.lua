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

local Browser = {
    m_browsers = {}
}
Browser.__index = Browser

-- create browser in coroutine, options { inflate = true, timeout = 8 }
function Browser.newBrowser(options)
    local thread = coroutine.running()
    if thread == nil then
        Log:error("browser should create from coroutine")
        return nil
    end
    local brw = {
        m_options = options, -- options like { inflate = true }
        m_chann = nil, -- one tcp chann
        m_hp = nil, -- hyperparser
        m_url_info = nil -- path, host, port
    }
    setmetatable(brw, Browser)
    if not Browser.m_has_init then
        Browser.m_has_init = true
    end
    brw.m_thread = thread
    return brw
end

-- act like curl, accept encoding gzip
local function _buildHttpRequest(method, url_info, options, data)
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
    tbl[#tbl + 1] = "User-Agent: curl/7.54.0"
    if options and options.inflate then
        tbl[#tbl + 1] = "Accept-Encoding: gzip"
    end
    if data then
        tbl[#tbl + 1] = "Content-Length: " .. data:len()
    end
    tbl[#tbl + 1] = "\n"
    if data then
        tbl[#tbl + 1] = data
    end
    return table.concat(tbl, "\n")
end

local function _processRecvData(brw, data)
    local ret, state, http_tbl = brw.m_hp:process(data)
    if ret < 0 then
        return ret
    end
    return ret, state, http_tbl
end

local function _constructContent(http_tbl, options)
    local input_content = table.concat(http_tbl.contents)
    http_tbl.contents = nil
    local output_content = nil
    local encoding_desc = http_tbl.header["Content-Encoding"] or http_tbl.header["content-encoding"]
    if encoding_desc == "gzip" and options.inflate then
        output_content = FileManager.inflate(input_content)
    else
        output_content = input_content
    end
    return output_content
end

-- return true/false, http_header, http_body, open one URL at a time
function Browser:openURL(site_url)
    if type(site_url) ~= "string" or self.m_thread ~= coroutine.running() then
        Log:error("please openURL from coroutine it created")
        return false
    end

    if self.m_chann then
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

    self.m_url_info = url_info
    Log:info("-- openURL %s", site_url)

    local ipv4 = nil
    local port = nil
    local ipv4_pattern = "%d-%.%d-%.%d-%.%d+"
    if url_info.host:find(ipv4_pattern) then
        ipv4 = url_info.host:match("(" .. ipv4_pattern .. ")")
        port = url_info.port
    else
        local timeout_second = self.m_options.timeout or AppEnv.Config.RPC_TIMEOUT
        local path_args = {["domain"] = url_info.host} -- use HTTP path query string, whatever key

        local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, {timeout = timeout_second}, path_args)
        if not success then
            Log:error("failed to dns '%s'", url_info.host)
            table.dump(datas)
            return false
        end

        datas = #datas > 0 and datas[1] or datas
        ipv4 = datas["ipv4"]
        port = url_info.port
    end

    if url_info.scheme == "http" then
        self.m_chann = TcpRaw.openChann()
        port = port and tonumber(port) or 80
    else
        self.m_chann = TcpSSL.openChann()
        port = port and tonumber(port) or 443
    end
    url_info = nil -- reset nil
    Log:info("get '%s' ipv4 '%s' with port '%d'", self.m_url_info.host, ipv4, port)

    local brw = self
    local callback = function(chann, event_name, _, _)
        if event_name == "event_connected" then
            brw.m_hp = HttpParser.createParser("RESPONSE")
            Log:info("site connected: %s", chann)
            local data = _buildHttpRequest("GET", brw.m_url_info, brw.m_options)
            chann:send(data)
            Log:info("send http request: %s", chann)
        elseif event_name == "event_recv" then
            local ret, state, http_tbl = _processRecvData(brw, chann:recv())
            if ret < 0 then
                Log:info("fail to process recv data")
                brw:closeURL()
                coroutine.resume(brw.m_thread, false)
            elseif state == HttpParser.STATE_BODY_FINISH and http_tbl then
                -- FIXME: consider status code 3XX
                -- FIXME: support cookies
                -- FIXME: support keep-alive
                brw:closeURL()
                local content = _constructContent(http_tbl, brw.m_options)
                coroutine.resume(brw.m_thread, true, http_tbl, content)
            end
        elseif event_name == "event_disconnect" then
            Log:info("site event disconnect: %s", chann)
            brw:closeURL()
            coroutine.resume(brw.m_thread, false)
        end
    end
    self.m_chann:setCallback(callback)
    self.m_chann:connectAddr(ipv4, port)
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
    if type(site_url) ~= "string" or self.m_thread ~= coroutine.running() then
        Log:error("please postURL from coroutine it created")
        return false
    end

    Log:error("postURL NOT supported right now")
    return false
end

function Browser:closeURL()
    Log:info("-- close URL: %s", self.m_url_info and self.m_url_info.host or "empty URL !")
    if self.m_chann then
        self.m_chann:closeChann()
        self.m_chann = nil
    end
    if self.m_hp then
        self.m_hp:destroy()
        self.m_hp = nil
    end
    self.m_url_info = nil
end

function Browser:onLoopEvent()
    if self.m_chann.onLoopEvent then
        return self.m_chann:onLoopEvent()
    end
    return true
end

return Browser
