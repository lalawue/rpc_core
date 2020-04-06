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

local lacInit = Core.thulac_init
local lacFini = Core.thulac_deinit
local lacSeg = Core.thulac_seg
local lacClean = Core.thulac_clean
local lacFetch = Core.thulac_fetch

local Lac = {
    ctx = nil
}
Lac.__index = Lac

-- create lac instance
function Lac.newLac(model_path, user_path, just_seg, t2s, ufilter)
    local ctx = lacInit(model_path, user_path, just_seg, t2s, ufilter)
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
        lacFini(self.ctx)
        self.ctx = nil
    end
end

-- return seg result count
function Lac:seg(str_in)
    if self.ctx == nil then
        return 0
    end
    return lacSeg(self.ctx, str_in)
end

-- clean last seg result
function Lac:clean()
    if self.ctx ~= nil then
        lacClean(self.ctx)
    end
end

local _word_tag = ffi.typeof("thulac_word_tag_t *")

-- fetch result from 1, not 0
function Lac:fetch(index)
    if self.ctx ~= nil then
        _word_tag = lacFetch(self.ctx, tonumber(index) - 1)
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
