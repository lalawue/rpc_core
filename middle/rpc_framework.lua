--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local NetCore = require("base.ffi_mnet")
local RpcDial = require("rpc_framework.rpc_dial.rpc_dial")
local RpcParser = require("rpc_framework.rpc_parser.rpc_parser")
local Log = require("middle.logger").newLogger("[RPC]", "trace")

-- Response for servce
--
local RpcResponse = {
    -- build http headers and send
    m_chann = nil,
    m_info = nil
}
RpcResponse.__index = RpcResponse

function RpcResponse.new(chann, rpc_info)
    local response = setmetatable({}, RpcResponse)
    response.m_chann = chann
    response.m_info = rpc_info
    return response
end

function RpcResponse:sendResponse(object)
    if self.m_chann == nil then
        Log:error("rpc_response invalid chann !")
        return
    end
    local dial = RpcDial.new()
    dial:responseMethod(self.m_info, nil, object)
    local packed = dial:makePackage()
    self.m_chann:send(packed)
end

-- Framework
--
local Framework = {}
Framework.__index = Framework

local AllChannsTimeTable = {} -- timeout table for chann
local AllChannsLoopTable = {} -- loop table for chann

function Framework.initFramework()
    if not Framework.m_has_init then
        Framework.m_has_init = true
        NetCore.init()
    end
end

local function _closeServiceChann(service_info, chann, rpc_parser, keep_alive)
    if rpc_parser then
        if keep_alive then
            Log:trace("'%s' keepalive: %s", service_info.name, chann)
        else
            Log:trace("'%s' disconnect: %s", service_info.name, chann)
            Framework.removeChannCallback(chann)
            chann:close()
            rpc_parser:destroy()
        end
    end
end

-- service_handler is a callback function(proto_info, request_object, rpc_response) end,
-- return false to shutdown connection
function Framework.newService(service_info, service_handler)
    if type(service_info) ~= "table" or type(service_handler) ~= "function" then
        Log:error("rpc_framework new service invalid params, %s", debug.traceback())
        return false
    end

    -- setup tcp listen
    local chann_listen = NetCore.openChann("tcp")
    chann_listen:listen(service_info.ipv4, service_info.port, 16)
    chann_listen:setCallback(
        function(_, _, accept, c_msg)
            if accept == nil then
                return
            end
            Log:info("'%s' connected: %s", service_info.name, accept)

            -- setup rpc parser
            local rpc_parser = RpcParser.newRequest(service_info)
            accept:setCallback(
                function(chann, event_name, _, _)
                    local to_close_chann = false
                    if event_name == "event_recv" then
                        local data = chann:recv()
                        if data then
                            local ret, proto_info, request_object = rpc_parser:process(data)
                            if ret < 0 then
                                to_close_chann = true
                            elseif proto_info then
                                local rpc_response = RpcResponse.new(chann, service_info)
                                to_close_chann = not service_handler(proto_info, request_object, rpc_response)
                            end
                        else
                            to_close_chann = true
                        end
                    elseif event_name == "event_disconnect" then
                        to_close_chann = true
                    end

                    if to_close_chann then
                        _closeServiceChann(service_info, chann, rpc_parser)
                        rpc_parser = nil
                    end
                end
            )
        end
    )

    Log:info("rpc_framework start service '%s' at '%s:%d'", service_info.name, service_info.ipv4, service_info.port)
    return true
end
--

-- call from coroutine, path_args and body_args refers to HTTP path and body
-- return 'true/false, return_object, reuse_info'
--[[
    option_args as {
        timeout = seconds,
        ipv4 = service_ipv4,
        keep_alive = keep_tcp_connection,
        reuse_info = connection_info of last newRequest return value,
    }
]] function Framework.newRequest(
    service_info,
    option_args,
    path_args,
    body_args)
    local thread = coroutine.running()
    if thread == nil then
        Log:error("rpc_framework request should call from coroutine")
        return false
    end
    if type(service_info) ~= "table" then
        Log:error("rpc_framework request params invalid, %s", debug.traceback())
        return false
    end

    local rpc_parser = RpcParser.newResponse(service_info)
    local chann = option_args.reuse_info or NetCore.openChann("tcp")
    if chann:state() == "state_connected" then
        Log:trace("'%s' reuseinfo: %s", service_info.name, chann)
        local request = RpcDial.new()
        request:callMethod(service_info, nil, path_args, body_args)
        local data = request:makePackage()
        chann:send(data)
    else
        local callback = function(chann, event_name, _, _)
            local to_resume = nil
            local ret_object = nil
            if event_name == "event_connected" then
                Log:trace("'%s' connected: %s", service_info.name, chann)
                local request = RpcDial.new()
                request:callMethod(service_info, nil, path_args, body_args)
                local data = request:makePackage()
                chann:send(data)
            elseif event_name == "event_recv" then
                local data = chann:recv()
                local ret, proto, response_object = rpc_parser:process(data)
                if ret < 0 then
                    to_resume = false
                elseif proto then
                    to_resume = true
                    ret_object = response_object
                end
            elseif event_name == "event_disconnect" then
                to_resume = false
            end

            if to_resume ~= nil then
                _closeServiceChann(service_info, chann, rpc_parser, option_args.keep_alive)
                if not option_args.keep_alive then
                    rpc_parser = nil
                end
                coroutine.resume(thread, to_resume, ret_object, chann)
            end
        end
        chann:setCallback(callback)
        --Log:debug("try connect %s", option_args.ipv4 or service_info.ipv4)
        chann:connect(option_args.ipv4 or service_info.ipv4, service_info.port)
        Framework.setupTimeoutCallback(chann, option_args.timeout or AppEnv.Config.BROWSER_TIMEOUT, callback)
    end
    return coroutine.yield() -- yeild recv or disconnect
end

-- callback function(chann, event_name)
function Framework.setupTimeoutCallback(chann, timeout_second, callback)
    if not chann or not timeout_second or not callback then
        Log:error("invalid timeout callback param")
        return
    end
    AllChannsTimeTable[tostring(chann)] = {
        ["start"] = os.time(),
        ["timeout"] = timeout_second,
        ["chann"] = chann,
        ["callback"] = callback
    }
    --Log:debug("setup timer callback %s", chann)
end

function Framework.removeChannCallback(chann)
    if not chann then
        Log:error("invalid chann")
        return
    end
    AllChannsTimeTable[tostring(chann)] = nil
    AllChannsLoopTable[chann] = nil
end

-- callback function(chann_key, "event_loop")
function Framework.setupLoopCallback(chann, callback)
    if chann and callback then
        AllChannsLoopTable[chann] = callback
    --Log:debug("setup loop callback %s", chann)
    end
end

local kOneSecondMs = 1000000

local function _tryCloseTimeoutRequest(current_time)
    for key, tbl in pairs(AllChannsTimeTable) do
        if os.difftime(current_time, tbl.start) >= tbl.timeout then
            Log:warn("newRequest timeout %s", key)
            if tbl.callback then
                tbl.callback(tbl.chann, "event_disconnect")
                tbl.callback = nil
                tbl.chann = nil
            end
            AllChannsTimeTable[key] = nil
        end
    end
end

local function _loopEvent()
    for chann, callback in pairs(AllChannsLoopTable) do
        callback(chann, "event_loop")
    end
end

function Framework.pollForever(callback, timeout_ms)
    timeout_ms = timeout_ms and tonumber(timeout_ms) or kOneSecondMs
    callback = type(callback) == "function" and callback or function()
        end
    local step_count = 1 -- step to update time
    while true do
        if step_count < AppEnv.Config.RPC_LOOP_CHECK then
            step_count = step_count + 1
        else
            step_count = 1
            _tryCloseTimeoutRequest(os.time())
        end
        _loopEvent()
        NetCore.poll(timeout_ms)
        callback()
    end
end

return Framework
