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
    _chann = nil,
    _info = nil
}
RpcResponse.__index = RpcResponse

function RpcResponse.new(chann, rpc_info)
    local response = setmetatable({}, RpcResponse)
    response._chann = chann
    response._info = rpc_info
    return response
end

function RpcResponse:sendResponse(object)
    if self._chann == nil then
        Log:error("rpc_response invalid chann !")
        return
    end
    local dial = RpcDial.new()
    dial:responseMethod(self._info, nil, object)
    local packed = dial:makePackage()
    self._chann:send(packed)
end

-- Framework
--
local Framework = {}
Framework.__index = Framework

local AllLoopCallbackTable = {} -- chann index in callback

function Framework.initFramework()
    if not Framework.m_has_init then
        Framework.m_has_init = true
        NetCore.init()
    end
end

local function _closeChannAndParser(service_info, chann, rpc_parser, keep_alive)
    if keep_alive then
        Log:trace("'%s' keepalive: %s", service_info.name, chann)
    elseif chann and rpc_parser then
        Log:trace("'%s' disconnect: %s", service_info.name, chann)
        chann:close()
        rpc_parser:destroy()
    end
end

-- service_handler is a callback function(proto_info, request_object, rpc_response) end,
-- service_handler return false to shutdown connection
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
                    local to_close = false
                    if event_name == "event_recv" then
                        local data = chann:recv()
                        if data then
                            local ret, proto_info, request_object = rpc_parser:process(data)
                            if ret < 0 then
                                to_close = true
                            elseif proto_info then
                                local rpc_response = RpcResponse.new(chann, service_info)
                                to_close = not service_handler(proto_info, request_object, rpc_response)
                            end
                        else
                            to_close = true
                        end
                    elseif event_name == "event_disconnect" then
                        to_close = true
                    end

                    if to_close then
                        _closeChannAndParser(service_info, chann, rpc_parser, false)
                    end
                end
            ) -- callback
        end
    )

    Log:info("rpc_framework start service '%s' at '%s:%d'", service_info.name, service_info.ipv4, service_info.port)
    return true
end

-- call from coroutine, path_args and body_args refers to HTTP path and body
-- return 'true/false, return_object, reuse_info'
--[[
    option_args as {
        timeout = seconds,
        ipv4 = service_ipv4,
        keep_alive = keep_tcp_connection,
        reuse_info = connection_info modified by framework
    }
]]
function Framework.newRequest(service_info, option_args, path_args, body_args)
    local thread = coroutine.running()
    if thread == nil then
        Log:error("rpc_framework request should call from coroutine")
        return false
    end
    if type(service_info) ~= "table" then
        Log:error("rpc_framework request params invalid, %s", debug.traceback())
        return false
    end

    -- reuse chann or create new one, assume service_info are the same
    local chann = option_args and option_args.reuse_info or NetCore.openChann("tcp")

    if chann:state() == "state_connected" then
        Log:trace("'%s' reuseinfo: %s", service_info.name, chann)
        local request = RpcDial.new()
        request:callMethod(service_info, nil, path_args, body_args)
        chann:send(request:makePackage())
    else
        -- create new chann then create new parser
        local rpc_parser = RpcParser.newResponse(service_info)
        local callback = function(chann, event_name, _, _)
            local to_resume = nil
            local ret_object = nil
            if event_name == "event_connected" then
                Log:trace("'%s' connected: %s", service_info.name, chann)
                local request = RpcDial.new()
                request:callMethod(service_info, nil, path_args, body_args)
                chann:send(request:makePackage())
            elseif event_name == "event_recv" then
                local ret, proto, response_object = rpc_parser:process(chann:recv())
                if ret < 0 then
                    to_resume = false
                elseif proto then
                    to_resume = true
                    ret_object = response_object
                end
            elseif event_name == "event_disconnect" or event_name == "event_timer" then
                to_resume = false
            end

            if to_resume ~= nil then
                _closeChannAndParser(service_info, chann, rpc_parser, option_args.keep_alive)
                option_args.reuse_info = option_args.keep_alive and chann or nil
                coroutine.resume(thread, to_resume, ret_object)
            end
        end
        chann:setCallback(callback)
        --Log:debug("try connect %s", option_args.ipv4 or service_info.ipv4)
        chann:connect(option_args.ipv4 or service_info.ipv4, service_info.port)
        chann:activeEvent("event_timer", tonumber(option_args.timeout or AppEnv.Config.RPC_TIMEOUT) * 1000000)
    end
    return coroutine.yield() -- yeild recv or disconnect
end

-- callback function(chann_key, "event_loop")
-- return index
function Framework.setLoopEvent(key, check_stop, finalizer)
    if not check_stop then
        Log:error("invalid loop callback")
    end
    AllLoopCallbackTable[key] = {check_stop = check_stop, finalizer = finalizer}
end

function Framework.pollForever(timeout_second)
    local millisecond = timeout_second and (tonumber(timeout_second) * 1000) or 1000
    local del_tbl = {}
    while true do
        for key, fn in pairs(AllLoopCallbackTable) do
            if fn.check_stop() then
                if fn.finalizer then
                    fn.finalizer()
                end
                del_tbl[#del_tbl + 1] = key
            end
        end
        for _, key in ipairs(del_tbl) do
            AllLoopCallbackTable[key] = nil
        end
        del_tbl[1] = nil
        NetCore.poll(millisecond)
    end
end

return Framework
