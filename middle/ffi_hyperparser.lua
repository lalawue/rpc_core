--
-- Copyright (c) 2019 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local ffi = require "ffi"

ffi.cdef [[
typedef enum {
   PROCESS_STATE_INVALID = 0,
   PROCESS_STATE_BEGIN = 1,     /* begin message */
   PROCESS_STATE_HEAD = 2,      /* header data comlete */
   PROCESS_STATE_BODY = 3,      /* begin body data */
   PROCESS_STATE_FINISH = 4     /* message finished */
} process_state_t;

typedef struct s_head_kv {
   char *head_field;
   char *head_value;
   struct s_head_kv *next;
} head_kv_t;

typedef struct s_data {
   unsigned char data[8192];
   int data_pos;
   struct s_data *next;
} data_t;

typedef struct s_http {
   process_state_t process_state; /*  */
   const char *method;
   char url[8192];
   uint16_t status_code;
   head_kv_t *head_kv;
   data_t *content;
   unsigned int content_length;
   unsigned int readed_length;
   const char *err_msg;
   void *opaque;                /* reserved */
} http_t;

/* 0:request 1:response 2:both */
http_t* mhttp_parser_create(int parser_type);
void mhttp_parser_destroy(http_t *h);

/* return byte processed, -1 means error */
int mhttp_parser_process(http_t *h, char *data, int length);

/* in BODY process_state, you can consume data blocks, 
 * minimize the memory usage, and last block may be a 
 * partial one
 */
void mhttp_parser_consume_data(http_t *h, int count);

/* reset http parser */
void mhttp_parser_reset(http_t *h);
]]

local hp = ffi.load("hyperparser")

local hp_create = hp.mhttp_parser_create
local hp_destroy = hp.mhttp_parser_destroy
local hp_process = hp.mhttp_parser_process
local hp_consume = hp.mhttp_parser_consume_data
local hp_reset = hp.mhttp_parser_reset

local k_url_len = 8192

local Parser = {
    STATE_HEAD_FINISH = 2, -- head infomation ready
    STATE_BODY_CONTINUE = 3, -- body infomation on going, chunked exp.
    STATE_BODY_FINISH = 4 -- body infomation ready
}
Parser.__index = Parser

local _intvalue = ffi.new("int", 0)
local _buf = ffi.new("char[?]", k_url_len)

function Parser.createParser(parserType)
    local parser = setmetatable({}, Parser)
    if parserType == "REQUEST" then
        _intvalue = 0
    elseif parserType == "RESPONSE" then
        _intvalue = 1
    else
        _intvalue = 2 -- both
    end
    parser._hp = hp_create(_intvalue)
    parser._state = -1
    parser._htbl = {}
    parser._data = ""
    return parser
end

function Parser:destroy()
    if self._hp then
        hp_destroy(self._hp)
        self._hp = nil
        self._state = -1
        self._htbl = nil
    end
end

local function _unpack_http(_hp, htbl)
    local method = ffi.string(_hp.method)
    if not method:find("<") then
        htbl.method = method
    end
    local status_code = tonumber(_hp.status_code)
    if status_code > 0 and status_code < 65535 then
        htbl.status_code = status_code
    end
    local content_length = tonumber(_hp.content_length)
    if content_length > 0 then
        htbl.content_length = content_length
    end
    htbl.readed_length = tonumber(_hp.readed_length)
    local url = ffi.string(_hp.url)
    if url:len() > 0 then
        htbl.url = url
    end
    if _hp.head_kv ~= nil and htbl.header == nil then
        htbl.header = {}
        local kv = _hp.head_kv
        while kv ~= nil do
            local field = kv.head_field
            local value = kv.head_value ~= nil and ffi.string(kv.head_value) or ""
            if field ~= nil then
                htbl.header[ffi.string(field)] = value
            else
                htbl.header[#htbl.header + 1] = value
            end
            kv = kv.next
        end
    end
    if _hp.content ~= nil then
        htbl.contents = htbl.contents or {}
        local data_count = 0
        local c = _hp.content
        while c ~= nil do
            data_count = data_count + 1
            htbl.contents[#htbl.contents + 1] = ffi.string(c.data, c.data_pos)
            c = c.next
        end
        hp_consume(_hp, data_count) -- consume data count from parser
    end
    if _hp.err_msg ~= nil then
        htbl.err_msg = ffi.string(_hp.err_msg)
    end
    return htbl
end

-- process input data, and holding left, only input new data
-- return nread, state, http_info_table
function Parser:process(data)
    assert(type(data) == "string", "invalid data type")
    local nread = 0
    local state = nil
    data = self._data .. data
    repeat
        _intvalue = data:len() < k_url_len and data:len() or k_url_len
        ffi.copy(_buf, data, _intvalue)
        nread = tonumber(hp_process(self._hp, _buf, _intvalue))
        state = tonumber(self._hp.process_state)
        if self._state ~= state then
            if state == hp.PROCESS_STATE_HEAD then
                self._htbl = _unpack_http(self._hp, self._htbl)
            elseif state == hp.PROCESS_STATE_BODY then
                self._htbl = _unpack_http(self._hp, self._htbl)
            elseif state == hp.PROCESS_STATE_FINISH then
                self._htbl = _unpack_http(self._hp, self._htbl)
                hp_reset(self._hp) -- reset when finish
            end
            self._state = state
        end
        data = data:len() > nread and data:sub(nread + 1) or ""
    until nread <= 0 or data:len() <= 0
    self._data = data
    return nread, self._state, self._htbl
end

-- reset parser, ready for next parse
function Parser:reset()
    self._state = -1
    self._htbl = {}
    self._data = ""
end

return Parser
