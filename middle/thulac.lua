--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local ffi = require("ffi")

ffi.cdef [[
typedef struct {
    const char *word;
    const char *tag;
} thulac_word_tag_t;

// default 'NULL, NULL, 0, 0, 0'
void* thulac_init(const char * model_path, const char* user_path, int just_seg, int t2s, int ufilter);
void thulac_deinit(void *ctx);

// return seg count
int thulac_seg(void *ctx, const char *in);

// fetch tag
thulac_word_tag_t* thulac_fetch(void *ctx, int index);

// clean last seg result
void thulac_clean(void *ctx);
]]

local Core = ffi.load("thulac")

local Lac = {
    ctx = nil
}
Lac.__index = Lac

-- create lac instance
function Lac.newLac(model_path, user_path, just_seg, t2s, ufilter)
    local ctx = Core.thulac_init(model_path, user_path, just_seg, t2s, ufilter)
    if ctx == nil then
        return nil
    end
    local lac = setmetatable({}, Lac)
    lac.ctx = ctx
    return lac
end

-- destroy lac instance
function Lac:fini()
    if self.ctx ~= nil then
        Core.thulac_deinit(self.ctx)
        self.ctx = nil
    end
end

-- return seg result count
function Lac:seg(str_in)
    if self.ctx ~= nil and type(str_in) == "string" then
        return Core.thulac_seg(self.ctx, str_in)
    end
    return 0
end

-- clean last seg result
function Lac:clean()
    if self.ctx ~= nil then
        Core.thulac_clean(self.ctx)
    end
end

local _word_tag = ffi.typeof("thulac_word_tag_t *")

-- fetch result from 1, not 0
function Lac:fetch(index)
    if self.ctx ~= nil then
        _word_tag = Core.thulac_fetch(self.ctx, tonumber(index) - 1)
        if _word_tag ~= nil then
            if _word_tag.tag ~= nil then
                return ffi.string(_word_tag.word), ffi.string(_word_tag.tag)
            else
                return ffi.string(_word_tag.word)
            end
        end
    end
    return nil
end

return Lac
