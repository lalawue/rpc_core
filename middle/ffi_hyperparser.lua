--
-- Copyright (c) 2019 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local ffi = require "ffi"

ffi.cdef[[
typedef enum {
   PROCESS_STATE_INVALID = 0,
   PROCESS_STATE_HEAD = 1,
   PROCESS_STATE_BODY = 2,
   PROCESS_STATE_FINISH = 3
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
]]

local hp = ffi.load("hyperparser")

local hp_create = hp.mhttp_parser_create
local hp_destroy = hp.mhttp_parser_destroy
local hp_process = hp.mhttp_parser_process

local k_url_len = 8192

local Parser = {
   STATE_HEAD_FINISH = 2,       -- head infomation ready
   STATE_BODY_FINISH = 3,       -- body infomation ready
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
      _intvalue = 2             -- both
   end
   parser.m_hp = hp_create(_intvalue)
   parser.m_state = -1
   parser.m_tbl = nil
   return parser
end

function Parser:destroy()
   if self.m_hp then
      hp_destroy(self.m_hp)
      self.m_hp = nil
      self.m_state = -1
      self.m_tbl = nil
   end
end

local function _unpack_http(m_hp)
   local tbl = {}
   local method = ffi.string(m_hp.method)
   if not method:find("<") then
      tbl.method = method
   end
   local status_code = tonumber(m_hp.status_code)
   if status_code > 0 and status_code < 65535 then
      tbl.status_code = status_code
   end
   local content_length = tonumber(m_hp.content_length)
   if content_length > 0 then
      tbl.content_length = content_length
   end
   tbl.readed_length = tonumber(m_hp.readed_length)
   local url = ffi.string(m_hp.url)
   if url:len() > 0 then
      tbl.url = url
   end
   if m_hp.head_kv ~= nil then
      tbl.header = {}
      local kv = m_hp.head_kv
      while kv ~= nil do
         local field = kv.head_field
         local value = kv.head_value ~= nil and ffi.string(kv.head_value) or ""
         if field ~= nil then
            tbl.header[ffi.string(field)] = value
         else
            tbl.header[#tbl.header + 1] = value
         end
         kv = kv.next
      end
   end
   if m_hp.content ~= nil then
      tbl.contents = {}
      local c = m_hp.content
      while c ~= nil do
         tbl.contents[#tbl.contents + 1] = ffi.string(c.data, c.data_pos)
         c = c.next
      end
   end
   if m_hp.err_msg ~= nil then
      tbl.err_msg = ffi.string(m_hp.err_msg)
   end
   return tbl
end

-- return nread, state, http_info_table
function Parser:process(data)
   local nread = 0
   local state = nil
   repeat
      _intvalue = data:len() < k_url_len  and data:len() or k_url_len
      ffi.copy(_buf, data, _intvalue)
      nread = tonumber(hp_process(self.m_hp, _buf, _intvalue))
      state = self.m_hp.process_state
      if self.m_state ~= tonumber(state) then
         if state == hp.PROCESS_STATE_BODY then
            self.m_tbl = _unpack_http(self.m_hp)            
         elseif state == hp.PROCESS_STATE_FINISH then
            self.m_tbl = _unpack_http(self.m_hp)
         end
         self.m_state = tonumber(state)
      end
   until nread <= 0 or data:len() > 0
   return nread, self.m_state, self.m_tbl
end

return Parser
