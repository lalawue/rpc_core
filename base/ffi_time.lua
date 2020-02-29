--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local ffi = require("ffi")

ffi.cdef [[
struct tm {
    int tm_sec;     /* seconds (0 - 60) */
    int tm_min;     /* minutes (0 - 59) */
    int tm_hour;    /* hours (0 - 23) */
    int tm_mday;    /* day of month (1 - 31) */
    int tm_mon;     /* month of year (0 - 11) */
    int tm_year;    /* year - 1900 */
    int tm_wday;    /* day of week (Sunday = 0) */
    int tm_yday;    /* day of year (0 - 365) */
    int tm_isdst;   /* is summer time in effect? */
    char *tm_zone;  /* abbreviation of timezone name */
    long tm_gmtoff; /* offset from UTC in seconds */
};

typedef int32_t time_t;
time_t time(time_t *dst_time);
struct tm *gmtime(const time_t *src_time);
time_t timegm(struct tm *timeptr);
]]

local _M = {}

-- return UTC time
function _M.timeUTC()
    local pt = ffi.new("time_t[1]")
    ffi.C.time(pt)
    return ffi.C.timegm(ffi.C.gmtime(pt))
end

function _M.tmUTC()
    local pt = ffi.new("time_t[1]")
    ffi.C.time(pt)
    local tm = ffi.C.gmtime(pt)
    tm.tm_year = tm.tm_year + 1900
    return tm
end

return _M
