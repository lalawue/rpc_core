--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local ffi = require("ffi")
local AppFramework = require("middle.app_framework")
local FileManager = require("middle.file_manager")
local Bitcask = require("middle.ffi_bitcask")
local Log = require("middle.logger").newLogger("[ObjDB]", "info")

-- object storage using redis resp_v2's 'SET/GET/DEL/KEYS', and 'SYNC' for sync linked objdb
--
local App = Class("ObjDB", AppFramework)

function App:initialize(app_name)
    -- create dir
    self._dir = AppEnv.Config.DATA_DIR .. "/objdb_data"
    FileManager.mkdir(self._dir)
end

-- ./bitraft/bitraft --bind '127.0.0.1:6379' --consistency low -d $PWD/data_master
function App:loadBusiness(rpc_framework)
    -- open database
    self:loadObjDB()
    -- start service
    rpc_framework.newService(
        AppEnv.Service.OBJDB_RESP,
        function(a, b, c)
            return App.processRequest(self, a, b, c)
        end
    )
end

function App:startBusiness(rpc_framework)
end

-- internal interface
--

-- main obj database
function App:loadObjDB()
    local config = {
        dir = self._dir,
        file_size = 128 * 1024 * 1024 -- 128MB
    }
    local db = Bitcask.opendb(config)
    if db then
        self._db = db
    else
        self._db = nil
        Log:error("failed to open bitcast in %s", self._dir)
        os.exit(0)
    end
end

function App:processRequest(proto_info, reqeust_object, rpc_response)
    local ret_tbl = nil
    local req_tbl = reqeust_object
    if type(req_tbl) == "table" and #req_tbl >= 2 and type(req_tbl[1]) == "string" and type(req_tbl[2]) == "string" then
        local cmd = reqeust_object[1]:upper()
        if cmd == "SET" then
            if #req_tbl >= 3 then
                self._db:set(req_tbl[2], req_tbl[3])
                ret_tbl = {"OK"}
            else
                ret_tbl = {"-invalid param count"}
            end
        elseif cmd == "GET" then
            local data = self._db:get(req_tbl[2])
            if type(data) == "string" then
                ret_tbl = {data}
            else
                ret_tbl = {nil}
            end
        elseif cmd == "DEL" then
            local ret = self._db:remove(req_tbl[2])
            if ret then
                ret_tbl = {1}
            else
                ret_tbl = {0}
            end
        elseif cmd == "GC" then
            self._db:gc("0") -- default db
            ret_tbl = {1}
        elseif cmd == "KEYS" then
            local tbl = {}
            local param = req_tbl[2] == "*" and ".+" or req_tbl[2]
            for _, key in ipairs(self._db:allKeys()) do
                if key:find(param) then
                    tbl[#tbl + 1] = key
                end
            end
            ret_tbl = {tbl}
        end
    end
    if ret_tbl then
        rpc_response:sendResponse(ret_tbl)
    end
end

return App
