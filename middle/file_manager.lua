-- 
-- Copyright (c) 2020 lalawue
-- 
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local FileSystem = require("base.ffi_lfs")
local Zlib = require("base.ffi_zlib")
local Log = require("middle.logger").newLogger("[FileManager]", "error")

local FileManager = {}
FileManager.__index = FileManager

function FileManager.mkdir(dir_path)
   FileSystem.mkdir(dir_path)
end

-- save data to path
function FileManager.saveFilePath(file_path, data)
   local f = io.open(file_path, "w+")
   if f then
      f:write(data)
      f:close()
      return true
   end
   return false
end

function FileManager.readAllContent(file_path)
   local f = io.open(file_path, "rb")
   if f then
      local data = f:read("*a")
      f:close()
      return data
   end
   return nil
end

function FileManager.inflateData(input_content)
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
      Log:error("zlib inflate error: %s", err_msg)
   end
   return table.concat(tbl)
end

function FileManager.deflateData(data)
   Log:error("not supported now")
end

return FileManager
