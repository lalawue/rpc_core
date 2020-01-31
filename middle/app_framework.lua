-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local RpcFramework = require("middle.rpc_framework")
local Log = require("middle.logger").newLogger("[App]", "info")

-- app framework, start app business in coroutine
local App = Class("AppFramework")

-- for subclass
-- function App:initialize(...)
-- end

-- launch app
function App:launch()
   RpcFramework.initFramework()
   Log:info("'%s' load business", self.class)
   self:loadBusiness( RpcFramework )
   local co = coroutine.create(function()
         Log:info("'%s' start business coroutine", self.class)
         self:startBusiness( RpcFramework )
   end)
   coroutine.resume(co)
   RpcFramework.pollForever(function()
         self:oneLoopInPoll( RpcFramework )
   end, self.m_poll_timeout_ms)
end

--
-- for subclass
-- 

-- for subclass, no coroutine
function App:loadBusiness(rpc_framework)
   -- load your business code here
end

-- for subclass, coroutine business
function App:startBusiness(rpc_framework)
   -- start your business code here
end

-- for subclass, one loop callback in poll
function App:oneLoopInPoll(rpc_framework)
   -- start your poll loop trigger code here
end

return App
