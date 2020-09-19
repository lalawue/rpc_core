--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local FileSystem = require("base.ffi_lfs")
local Zlib = require("base.ffi_zlib")

local FileManager = {}

function FileManager.mkdir(dir_path)
    FileSystem.mkdir(dir_path)
end

function FileManager.stat(path)
    return FileSystem.attributes(path)
end

local _dummy_tbl = {}

-- list dir files, tbl_modes should be { "files" = true, "directory" = true }
function FileManager.listDir(dir_path, tbl_modes)
    if type(dir_path) ~= "string" or type(tbl_modes) ~= "table" then
        return _dummy_tbl
    end
    local attr = FileSystem.attributes(dir_path)
    if type(attr) ~= "table" or attr.mode ~= "directory" then
        return _dummy_tbl
    end
    local tbl = {}
    for fname in FileSystem.dir(dir_path) do
        attr = FileSystem.attributes(dir_path .. "/" .. fname)
        if attr and tbl_modes[attr.mode] then
            tbl[#tbl + 1] = fname
        end
    end
    return tbl
end

-- save data to path
function FileManager.saveFile(file_path, data)
    local f = io.open(file_path, "wb")
    if f then
        f:write(data)
        f:close()
        return true
    end
    return false
end

function FileManager.readFile(file_path)
    local f = io.open(file_path, "rb")
    if f then
        local data = f:read("*a")
        f:close()
        return data
    end
    return nil
end

function FileManager.appendFile(file_path, data)
    local f = io.open(file_path, "a+")
    if f then
        f:write(data)
        f:close()
        return true
    end
    return false
end

function FileManager.removeFile(file_path)
    os.remove(file_path)
end

function FileManager.renameFile(oldname, newname)
    os.rename(oldname, newname)
end

function FileManager.inflate(input_content)
    if type(input_content) ~= "string" then
        return nil
    end
    local function _input(buf_size)
        local min_len = math.min(buf_size, input_content:len())
        if min_len > 0 then
            local data = input_content:sub(1, min_len)
            input_content = input_content:sub(1 + min_len)
            return data
        end
    end
    local tbl = {}
    local function _ouput(data)
        tbl[#tbl + 1] = data
    end
    local success, err_msg = Zlib.inflateGzip(_input, _ouput)
    if not success then
        return table.concat(tbl), err_msg
    end
    return table.concat(tbl)
end

function FileManager.deflate(input_content)
    if type(input_content) ~= "string" then
        return nil
    end
    local function _input(buf_size)
        local min_len = math.min(buf_size, input_content:len())
        if min_len > 0 then
            local data = input_content:sub(1, min_len)
            input_content = input_content:sub(1 + min_len)
            return data
        end
    end
    local tbl = {}
    local function _ouput(data)
        tbl[#tbl + 1] = data
    end
    local success, err_msg = Zlib.deflateGzip(_input, _ouput)
    if not success then
        return table.concat(tbl), err_msg
    end
    return table.concat(tbl)
end

return FileManager
