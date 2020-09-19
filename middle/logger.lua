--
-- Copyright (c) 2019 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local _M = {
    _name = "[Logger] ",
    _level = 1
}
_M.__index = _M

local _level_name_number = {
    ["debug"] = 1,
    ["trace"] = 2,
    ["info"] = 3,
    ["warn"] = 4,
    ["error"] = 5
}

local _fpTagPrintf = function(...)
end

-- set output file in app:initialize()
function _M.setOutputFile(file_path)
    local fp = (type(file_path) == "string") and io.open(file_path, "ab+") or nil
    if fp then
        _fpTagPrintf = function(content)
            fp:write(content .. "\n")
            fp:flush()
        end
    end
end

-- 'debug', 'info', 'warn', 'error'
function _M.newLogger(tag_name, level_name)
    local ins = setmetatable({}, _M)
    ins._name = tag_name and (tag_name .. " ") or "[Log] "
    ins._level = _level_name_number[level_name] or 1
    local tbl = {}
    for k, v in pairs(_level_name_number) do
        tbl[tonumber(v)] = k:sub(1, 1):upper() .. "." .. tag_name .. " "
    end
    ins._tags = tbl

    return ins
end

function _M:_log(level_name, fmt, ...)
    local number = _level_name_number[level_name] or 5
    if number >= self._level then
        local tag = self._tags[number]
        print(tag .. string.format(fmt, ...))
        _fpTagPrintf(tag .. string.format(fmt, ...))
    end
end

function _M:error(fmt, ...)
    self:_log("error", fmt, ...)
end

function _M:warn(fmt, ...)
    self:_log("warn", fmt, ...)
end

function _M:info(fmt, ...)
    self:_log("info", fmt, ...)
end

function _M:trace(fmt, ...)
    self:_log("trace", fmt, ...)
end

function _M:debug(fmt, ...)
    self:_log("debug", fmt, ...)
end

return _M
