-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local NetCore = require("base.ffi_mnet")
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
      m_options = options,      -- options like { inflate = true }
      m_chann = nil,            -- one tcp chann
      m_hp = nil,               -- hyperparser      
      m_left_data = nil,        -- left http protocol data      
      m_url_info = nil,         -- path, host, port
   }
   setmetatable(brw, Browser)
   if not Browser.m_has_init then
      Browser.m_has_init = true
      NetCore.init()
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
   local sub_path = '/'
   if url_info.path and url_info.path:len() > 0 then
      sub_path = url_info.path
   end
   if type(url_info.query) == 'table' then
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
   if brw.m_left_data then
      data = brw.m_left_data .. data
      brw.m_left_data = nil
   end
   local ret, state, http_tbl = brw.m_hp:process(data)
   if ret < 0 then
      return ret
   end
   if ret > 0 and ret < data:len() then
      brw.m_left_data = data:sub(ret + 1)
   end
   return ret, state, http_tbl
end

local function _constructContent(http_tbl, options)
   local input_content = table.concat(http_tbl.contents)
   http_tbl.contents = nil
   local output_content = nil
   if http_tbl.header["Content-Encoding"] == "gzip" and options.inflate then
      output_content = FileManager.inflateData( input_content )
   else
      output_content = input_content
   end
   return output_content
end

-- return true/false, http_header, http_body, open one URL at a time
function Browser:openURL( site_url )
   if type(site_url) ~= "string" or
      self.m_thread ~= coroutine.running()
   then
      Log:error("please openURL from coroutine it created")      
      return false
   end

   local url = UrlCore.parse( site_url )
   if not url then
      Log:error("fail to parse url '%s'", site_url)
      return false
   end
   self.m_url_info = url
   Log:info("-- openURL %s", site_url)

   local timeout_second = self.m_options.timeout or AppEnv.Config.BROWSER_TIMEOUT
   local path_args = { ["domain"] = url.host } -- use HTTP path query string, whatever key
   local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, { timeout = timeout_second }, path_args)
   --local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_JSON, { timeout = timeout_second }, nil, path_args )
   --local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_SPROTO, { timeout = timeout_second }, path_args)
   --local success, datas = RpcFramework.newRequest(AppEnv.Service.DNS_SPROTO, { timeout = timeout_second }, nil, path_args )
   if not success then
      Log:error("rpc failed ! %s", success)
      table.dump(datas)
      return false
   end

   datas = #datas > 0 and datas[1] or datas
   local ipv4 = datas["ipv4"]
   Log:info("get '%s' ipv4 '%s'", url.host, ipv4)

   if not self.m_chann then
      local brw = self
      self.m_chann = NetCore.openChann("tcp")
      local callback = function(chann, event_name, _, _)
            if event_name == "event_connected" then
               brw.m_hp = HttpParser.createParser("RESPONSE")
               Log:info("site connected: %s", chann)
               local data = _buildHttpRequest("GET", brw.m_url_info, brw.m_options)
               chann:send( data )
               Log:info("send http request: %s", chann)
            elseif event_name == "event_recv" then
               local ret, state, http_tbl = _processRecvData( brw, chann:recv() )
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
      self.m_chann:setCallback( callback )
      local port = url.port and tonumber(url.port) or 80
      self.m_chann:connect(ipv4, port)
      RpcFramework.setupTimeoutCallback(self.m_chann, timeout_second, callback)
      Log:info("try connect %s:%d", ipv4, port)
   end
   return coroutine.yield()
end

-- return true/false, http header, data, one at a time
function Browser:postURL( site_url, data )
   if type(site_url) ~= "string" or
      self.m_thread ~= coroutine.running()
   then
      Log:error("please postURL from coroutine it created")
      return false
   end

   Log:error("postURL NOT supported right now")
   return false
end

function Browser:closeURL()
   Log:info("-- close URL: %s", self.m_url_info.host)
   if self.m_chann then
      self.m_chann:close()
      RpcFramework.removeTimeoutCallback(self.m_chann)
      self.m_chann = nil
   end
   if self.m_hp then
      self.m_hp:destroy()
      self.m_hp = nil
   end
   self.m_left_data = nil
   self.m_url_info = nil
end

return Browser
