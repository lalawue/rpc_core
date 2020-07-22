--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

-- export to global

local serpent = require("base.serpent")

-- string
--

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

-- table
--

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

local function _deep_copy(object, lookup_table)
    if type(object) ~= "table" then
        return object
    elseif lookup_table[object] then
        return lookup_table[object]
    end
    local new_object = {}
    lookup_table[object] = new_object
    for key, value in pairs(object) do
        new_object[_deep_copy(key, lookup_table)] = _deep_copy(value, lookup_table)
    end
    return setmetatable(new_object, getmetatable(object))
end

if table.clone == nil then
    function table.clone(o)
        return _deep_copy(o, {})
    end
end

-- is empty
if table.isempty == nil then
    function table.isempty(t)
        return type(t) == "table" and _G.next(t) == nil
    end
end

if table.isarray == nil then
    function table.isarray(t)
        if type(t) ~= "table" then
            return false
        end
        local i = 0
        for _ in pairs(t) do
            i = i + 1
            if t[i] == nil then
                return false
            end
        end
        return true
    end
end

-- io
--

io.printf = function(fmt, ...)
    if not fmt then
        os.exit(0)
    end
    print(string.format(fmt, ...))
end

-- language
--

Lang = {}

-- validate input parameter is valid type described in type_desc, only 1 depth
local _type_string = {
    ["I"] = "nil",
    ["N"] = "number",
    ["S"] = "string",
    ["B"] = "boolean",
    ["T"] = "table",
    ["F"] = "function",
    ["D"] = "thread",
    ["U"] = "userdata"
}
function Lang.valid(type_desc, ...)
    for i = 1, type_desc:len(), 1 do
        local val = select(i, ...)
        if type(val) ~= _type_string[type_desc:sub(i, i)] then
            return false
        end
    end
    return true
end
