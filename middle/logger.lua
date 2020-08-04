--
-- Copyright (c) 2019 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local Logger = {
   _name = "[Logger] ",
   _level = 1
}
Logger.__index = Logger

local _level_name_number = {
   ["debug"] = 1,
   ["trace"] = 2,
   ["info"] = 3,
   ["warn"] = 4,
   ["error"] = 5
}

local function tag_printf(tag, fmt, ...)
   print(tag .. string.format(fmt, ...))
end

-- 'debug', 'info', 'warn', 'error'
function Logger.newLogger(tag_name, level_name)
   local logger = setmetatable({}, Logger)
   logger._name = tag_name and (tag_name .. " ") or "[Log] "
   logger._level = _level_name_number[level_name] or 1
   local tbl = {}
   for k, v in pairs(_level_name_number) do
      tbl[tonumber(v)] = k:sub(1,1):upper() .. "." .. tag_name .. " "
   end
   logger._tags = tbl
   return logger
end

function Logger:log(level_name, fmt, ...)
   local number = _level_name_number[level_name] or 5
   if number >= self._level then
      tag_printf(self._tags[number], fmt, ...)
   end
end

function Logger:error(fmt, ...)
   self:log("error", fmt, ...)
end

function Logger:warn(fmt, ...)
   self:log("warn", fmt, ...)
end

function Logger:info(fmt, ...)
   self:log("info", fmt, ...)
end

function Logger:trace(fmt, ...)
   self:log("trace", fmt, ...)
end

function Logger:debug(fmt, ...)
   self:log("debug", fmt, ...)
end

return Logger
