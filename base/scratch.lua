--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

-- export to global

local serpent = require("base.serpent")

function string:split(sSeparator, nMax, bRegexp)
    assert(sSeparator ~= "")
    assert(nMax == nil or nMax >= 1)
    local aRecord = {}
    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1
        local nField, nStart = 1, 1
        local nFirst, nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst - 1)
            nField = nField + 1
            nStart = nLast + 1
            nFirst, nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax - 1
        end
        aRecord[nField] = self:sub(nStart)
    else
        aRecord[1] = ""
    end
    return aRecord
end

table.dump = function(tbl)
    print(serpent.block(tbl))
end

-- return a readonly table
table.readonly = function(tbl, err_message)
    return setmetatable(
        {},
        {
            __index = tbl,
            __newindex = function(t, k, v)
                error(err_message, 2)
            end
        }
    )
end

io.printf = function(fmt, ...)
    if not fmt then
        os.exit(0)
    end
    print(string.format(fmt, ...))
end

Lang = {}

local function isAllType(name, ...)
    for i = 1, 65536, 1 do
        local input = select(i, ...)
        if input == nil then
            return i > 1
        elseif type(input) ~= name then
            return false
        end
    end
    return false
end

function Lang.isString(...)
    return isAllType("string", ...)
end

function Lang.isTable(...)
    return isAllType("table", ...)
end

function Lang.isFunction(...)
    return isAllType("function", ...)
end
