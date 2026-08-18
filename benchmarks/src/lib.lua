--- Shared helpers for the rapidhash in-process benchmarks.
---
--- The benchmark entry (src/init.lua) runs inside lde's profiled guest state
--- when invoked with `lde run --profile`, so every frame below a phase lands
--- in the profile. Phases are named functions owning their own calibrated
--- loop (LuaJIT's profiler names frames by call-site operand, so a loop in a
--- generic helper would flatten every phase into one anonymous frame).

local ffi = require("ffi")

local lib = {}

ffi.cdef [[
	typedef struct { long tv_sec; long tv_nsec; } timespec;
	int clock_gettime(int clk_id, timespec *tp);
]]

---@return number # monotonic wall clock, nanoseconds
function lib.now()
	local t = ffi.new("timespec")
	ffi.C.clock_gettime(1, t) -- CLOCK_MONOTONIC
	---@diagnostic disable-next-line: undefined-field
	return tonumber(t.tv_sec) * 1e9 + tonumber(t.tv_nsec)
end

---@class bench.Result
---@field name string
---@field ms number
---@field iters integer
---@field opsPerSec number
---@field mbPerSec number?

---@type bench.Result[]
local results = {}

--- Record a finished phase (called by the phase function itself after its
--- calibrated loop, so the profile keeps clean attribution).
---@param name string
---@param iters integer
---@param ms number
---@param bytesPerOp integer?
function lib.record(name, iters, ms, bytesPerOp)
	local opsPerSec = ms > 0 and (iters / (ms / 1000)) or 0
	results[#results + 1] = {
		name = name,
		ms = ms,
		iters = iters,
		opsPerSec = opsPerSec,
		mbPerSec = bytesPerOp and (opsPerSec * bytesPerOp / 1e6) or nil,
	}
end

--- How many iterations of `once` fit in `targetMs` of wall time? Runs `once`
--- a single time to measure, so phases occupy a similar budget on any machine
--- (and produce enough samples at the 1ms profiler interval).
---@param once fun()
---@param targetMs number
---@return integer
function lib.calibrate(once, targetMs)
	local t0 = lib.now()
	once()
	local oneMs = (lib.now() - t0) / 1e6
	if oneMs <= 0 then return 1000000 end
	return math.max(1, math.min(10000000, math.ceil(targetMs / oneMs)))
end

--- Print the per-phase table (also usable outside profiling runs).
function lib.printResults()
	print("\n=== Phase results ===")
	print(string.format("  %-22s %10s %12s %10s %10s", "phase", "time", "iters", "ops/sec", "MB/s"))
	local totalMs = 0
	for _, r in ipairs(results) do
		totalMs = totalMs + r.ms
		print(string.format("  %-22s %8.0fms %12d %10.0f %10.1f",
			r.name, r.ms, r.iters, r.opsPerSec, r.mbPerSec or 0))
	end
	print(string.format("  %-22s %8.0fms", "total", totalMs))
end

return lib
