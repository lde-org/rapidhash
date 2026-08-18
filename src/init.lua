local ffi = require("ffi")

ffi.cdef [[
	uint64_t rapidhash_core_hash(const void *key, size_t len, uint64_t seed);
]]

local here = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or ""
local libname = jit.os == "Windows" and "rapidhash_core.dll" or (jit.os == "OSX" and "rapidhash_core.dylib" or "rapidhash_core.so")
local core = ffi.load(here .. libname)

local rapidhash = {}

---@param s string  Input buffer.
---@param seed (number|ffi.cdata*)?
---@return ffi.cdata* 64-bit hash.
function rapidhash.hash(s, seed)
	return core.rapidhash_core_hash(s, #s, seed or 0)
end

---@param s string  Input buffer.
---@param seed (number|ffi.cdata*)?
---@return string Lowercase 16-digit hex hash.
function rapidhash.hex(s, seed)
	return string.format("%016x", rapidhash.hash(s, seed))
end

return rapidhash
