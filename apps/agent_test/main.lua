--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local AppFramework = require("middle.app_framework")
local Browser = require("middle.http_browser")
local Log = require("middle.logger").newLogger("[Test]", "info")

local Test = Class("Test", AppFramework)

function Test:initialize(app_name, arg_1)
   self.m_app_name = app_name
   self.m_domain = arg_1
   Log:info("Test init with %s", app_name)
end

function Test:loadBusiness(rpc_framework)
   -- as client, do nothing here
end

function Test:startBusiness(rpc_framework)
   local browser = Browser.newBrowser({ timeout = 30, inflate = true })
   local success, http_header, content = browser:openURL(self.m_domain)
   Log:info("reqeust result: %s", success)
   table.dump(http_header)
   Log:info("content length: %d", content:len())
   -- Log:info("content %s", content)
   os.exit(0)
end

return Test
