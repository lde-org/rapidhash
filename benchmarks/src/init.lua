--- In-process benchmarks for the rapidhash package.
---
--- Scenarios: a size sweep across every branch of the algorithm (short <=16,
--- tail 17-112, single and multi 112-byte loop iterations, large inputs),
--- hex output (the formatting cost), realistic lockfile/config-shaped text,
--- seed handling (cdata vs Lua number), and a head-to-head with the
--- byte-at-a-time fnv1a that lde currently uses for cache stamps.
---
--- Run from the benchmarks dir:
---   lde run                          # benchmark only (prints a phase table)
---   lde run --profile --json out.json # sampled profile of every phase
---
--- Optional scale argument multiplies the per-phase budgets:
---   lde run -- 3

local lib = require("benchmarks.lib")
local rapidhash = require("rapidhash")

local band, bxor = bit.band, bit.bxor
local scale = tonumber(arg and arg[1]) or 1

-- ── Fixtures ──────────────────────────────────────────────────────────────
-- Deterministic pseudo-random bytes (same generator as the test vectors, so
-- sizes exercise the exact branch boundaries from the tests).
---@param len integer
---@return string
local function makeInput(len)
	local t = {}
	for i = 0, len - 1 do
		t[i + 1] = string.char(band(i * 37 + 11, 255))
	end
	return table.concat(t)
end

-- Realistic lde-shaped data: a lockfile for a ~120-dep project (git deps
-- with pinned commits), and a small package manifest.
local lockfileText
do
	local parts = { '{\n\t"version": "1",\n\t"dependencies": {' }
	for i = 1, 120 do
		parts[#parts + 1] = string.format('\t\t"dep%03d": {\n\t\t\t"git": "https://github.com/example/repo-%d.git",\n\t\t\t"commit": "%s"\n\t\t}', i, i, string.rep(string.format("%02x", i), 20))
		if i < 120 then parts[#parts + 1] = "," end
	end
	parts[#parts + 1] = "\t}\n}"
	lockfileText = table.concat(parts)
end

local manifestText = '{\n\t"name": "my-package",\n\t"version": "0.1.0",\n\t"dependencies": {\n\t\t"json": { "path": "../json" },\n\t\t"hood": { "git": "https://github.com/example/hood", "commit": "abc123" },\n\t\t"semver": { "version": "1.0.0" }\n\t}\n}\n'

-- The byte-at-a-time FNV-1a lde currently uses (packages/util/src/init.lua),
-- included here as the baseline to beat.
---@param s string
---@return string
local function fnv1a(s)
	local h = 2166136261
	for i = 1, #s do
		h = band(bxor(h, string.byte(s, i)) * 16777619, 0xFFFFFFFF)
	end
	return string.format("%08x", band(h, 0xFFFFFFFF))
end

local input8    = makeInput(8)
local input64   = makeInput(64)
local input100  = makeInput(100)
local input113  = makeInput(113) -- enters the 112-byte loop exactly once
local input300  = makeInput(300) -- two 112-byte loop iterations
local input1k   = makeInput(1024)
local input64k  = makeInput(65536)
local input1m   = makeInput(1048576)
local input512  = makeInput(512)

-- ── Size sweep (hash, seed 0) ─────────────────────────────────────────────
local N_HASH_8 = lib.calibrate(function() rapidhash.hash(input8) end, 250 * scale)
local N_HASH_64 = lib.calibrate(function() rapidhash.hash(input64) end, 250 * scale)
local N_HASH_100 = lib.calibrate(function() rapidhash.hash(input100) end, 250 * scale)
local N_HASH_113 = lib.calibrate(function() rapidhash.hash(input113) end, 250 * scale)
local N_HASH_300 = lib.calibrate(function() rapidhash.hash(input300) end, 250 * scale)
local N_HASH_1K = lib.calibrate(function() rapidhash.hash(input1k) end, 250 * scale)
local N_HASH_64K = lib.calibrate(function() rapidhash.hash(input64k) end, 250 * scale)
local N_HASH_1M = lib.calibrate(function() rapidhash.hash(input1m) end, 250 * scale)

local function bench_hash_8()
	local t0 = lib.now()
	for _ = 1, N_HASH_8 do rapidhash.hash(input8) end
	lib.record("hash 8B", N_HASH_8, (lib.now() - t0) / 1e6, 8)
end

local function bench_hash_64()
	local t0 = lib.now()
	for _ = 1, N_HASH_64 do rapidhash.hash(input64) end
	lib.record("hash 64B", N_HASH_64, (lib.now() - t0) / 1e6, 64)
end

local function bench_hash_100()
	local t0 = lib.now()
	for _ = 1, N_HASH_100 do rapidhash.hash(input100) end
	lib.record("hash 100B", N_HASH_100, (lib.now() - t0) / 1e6, 100)
end

local function bench_hash_113()
	local t0 = lib.now()
	for _ = 1, N_HASH_113 do rapidhash.hash(input113) end
	lib.record("hash 113B", N_HASH_113, (lib.now() - t0) / 1e6, 113)
end

local function bench_hash_300()
	local t0 = lib.now()
	for _ = 1, N_HASH_300 do rapidhash.hash(input300) end
	lib.record("hash 300B", N_HASH_300, (lib.now() - t0) / 1e6, 300)
end

local function bench_hash_1k()
	local t0 = lib.now()
	for _ = 1, N_HASH_1K do rapidhash.hash(input1k) end
	lib.record("hash 1KB", N_HASH_1K, (lib.now() - t0) / 1e6, 1024)
end

local function bench_hash_64k()
	local t0 = lib.now()
	for _ = 1, N_HASH_64K do rapidhash.hash(input64k) end
	lib.record("hash 64KB", N_HASH_64K, (lib.now() - t0) / 1e6, 65536)
end

local function bench_hash_1m()
	local t0 = lib.now()
	for _ = 1, N_HASH_1M do rapidhash.hash(input1m) end
	lib.record("hash 1MB", N_HASH_1M, (lib.now() - t0) / 1e6, 1048576)
end

-- ── Hex output (hash + %016x formatting) ──────────────────────────────────
local N_HEX_1K = lib.calibrate(function() rapidhash.hex(input1k) end, 250 * scale)

local function bench_hex_1k()
	local t0 = lib.now()
	for _ = 1, N_HEX_1K do rapidhash.hex(input1k) end
	lib.record("hex 1KB", N_HEX_1K, (lib.now() - t0) / 1e6, 1024)
end

-- ── Realistic text ────────────────────────────────────────────────────────
local N_LOCKFILE = lib.calibrate(function() rapidhash.hash(lockfileText) end, 250 * scale)
local N_MANIFEST = lib.calibrate(function() rapidhash.hash(manifestText) end, 250 * scale)

local function bench_hash_lockfile()
	local t0 = lib.now()
	for _ = 1, N_LOCKFILE do rapidhash.hash(lockfileText) end
	lib.record("hash lockfile", N_LOCKFILE, (lib.now() - t0) / 1e6, #lockfileText)
end

local function bench_hash_manifest()
	local t0 = lib.now()
	for _ = 1, N_MANIFEST do rapidhash.hash(manifestText) end
	lib.record("hash manifest", N_MANIFEST, (lib.now() - t0) / 1e6, #manifestText)
end

-- ── Seeds ─────────────────────────────────────────────────────────────────
local N_SEED_CDATA = lib.calibrate(function() rapidhash.hash(input1k, 0x123456789abcdef0ULL) end, 250 * scale)
local N_SEED_NUM = lib.calibrate(function() rapidhash.hash(input1k, 1234567890) end, 250 * scale)

local function bench_seed_cdata()
	local t0 = lib.now()
	for _ = 1, N_SEED_CDATA do rapidhash.hash(input1k, 0x123456789abcdef0ULL) end
	lib.record("seed cdata 1KB", N_SEED_CDATA, (lib.now() - t0) / 1e6, 1024)
end

local function bench_seed_number()
	local t0 = lib.now()
	for _ = 1, N_SEED_NUM do rapidhash.hash(input1k, 1234567890) end
	lib.record("seed number 1KB", N_SEED_NUM, (lib.now() - t0) / 1e6, 1024)
end

-- ── fnv1a baseline ────────────────────────────────────────────────────────
local N_FNV_1K = lib.calibrate(function() fnv1a(input1k) end, 250 * scale)
local N_FNV_64K = lib.calibrate(function() fnv1a(input64k) end, 250 * scale)
local N_FNV_LOCK = lib.calibrate(function() fnv1a(lockfileText) end, 250 * scale)

local function bench_fnv1a_1k()
	local t0 = lib.now()
	for _ = 1, N_FNV_1K do fnv1a(input1k) end
	lib.record("fnv1a 1KB", N_FNV_1K, (lib.now() - t0) / 1e6, 1024)
end

local function bench_fnv1a_64k()
	local t0 = lib.now()
	for _ = 1, N_FNV_64K do fnv1a(input64k) end
	lib.record("fnv1a 64KB", N_FNV_64K, (lib.now() - t0) / 1e6, 65536)
end

local function bench_fnv1a_lockfile()
	local t0 = lib.now()
	for _ = 1, N_FNV_LOCK do fnv1a(lockfileText) end
	lib.record("fnv1a lockfile", N_FNV_LOCK, (lib.now() - t0) / 1e6, #lockfileText)
end

-- ── Run ───────────────────────────────────────────────────────────────────
bench_hash_8()
bench_hash_64()
bench_hash_100()
bench_hash_113()
bench_hash_300()
bench_hash_1k()
bench_hash_64k()
bench_hash_1m()
bench_hex_1k()
bench_hash_lockfile()
bench_hash_manifest()
bench_seed_cdata()
bench_seed_number()
bench_fnv1a_1k()
bench_fnv1a_64k()
bench_fnv1a_lockfile()

print("rapidhash-bench-done")

lib.printResults()
