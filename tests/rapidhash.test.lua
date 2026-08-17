-- Tests for the LuaJIT port of rapidhash (Nicoshev/rapidhash V3).
--
-- The vectors in tests/vectors.lua were generated with the reference C
-- implementation (rapidhash.h, RAPIDHASH_FAST | RAPIDHASH_COMPACT),
-- so they are the authoritative expected outputs.

local test = require("lde-test")
local rapidhash = require("rapidhash")

---Formats a uint64 cdata as a 16-digit lowercase hex string.
local function hex64(v)
  return string.format("%08x", tonumber(bit.rshift(v, 32)))
    .. string.format("%08x", tonumber(bit.band(v, 0x00000000ffffffffULL)))
end

---Deterministic input generator, shared with the C vector generator:
---byte i (0-based) = (i * 37 + 11) & 0xFF.
local function makeInput(len)
  local t = {}
  for i = 0, len - 1 do
    t[i + 1] = string.char(bit.band(i * 37 + 11, 255))
  end
  return table.concat(t)
end

---Builds a string from a byte array (for the binary-data vectors).
local function bytesToStr(bytes)
  local t = {}
  for i, b in ipairs(bytes) do
    t[i] = string.char(b)
  end
  return table.concat(t)
end

local vectors = require("tests.vectors")

test.it("matches the reference C implementation on every vector", function()
  for _, v in ipairs(vectors) do
    local input
    if v.bytes then
      input = bytesToStr(v.bytes)
    elseif v.len ~= nil then
      input = makeInput(v.len)
    else
      input = v.str
    end
    test.equal(hex64(rapidhash.hash(input, v.seed)), hex64(v.hash))
  end
end)

test.it("covers every branch boundary of the algorithm", function()
  -- lengths just below/at/above each threshold in rapidhash_internal
  local lengths = { 0, 1, 3, 4, 7, 8, 15, 16, 17, 31, 32, 33, 47, 48, 49,
                    63, 64, 65, 79, 80, 81, 95, 96, 97, 111, 112, 113, 160,
                    224, 225, 256, 384, 512, 1024, 4096, 65535 }
  for _, len in ipairs(lengths) do
    -- rapidHash must agree with hash(seed = 0)
    test.equal(
      hex64(rapidhash.hash(makeInput(len))),
      hex64(rapidhash.hash(makeInput(len), 0))
    )
  end
end)

test.it("accepts number seeds and cdata seeds interchangeably", function()
  test.equal(
    hex64(rapidhash.hash("abc", 1)),
    hex64(rapidhash.hash("abc", 1ULL))
  )
  test.equal(
    hex64(rapidhash.hash("abc", 2 ^ 32)),
    hex64(rapidhash.hash("abc", 0x100000000ULL))
  )
  -- negative number seeds wrap to their two's complement 64-bit pattern
  test.equal(
    hex64(rapidhash.hash("abc", -1)),
    hex64(rapidhash.hash("abc", 0xffffffffffffffffULL))
  )
end)

test.it("rapidHashHex formats the hash as lowercase hex", function()
  test.equal(rapidhash.hex(""), "0338dc4be2cecdae")
  test.equal(
    rapidhash.hex("The quick brown fox jumps over the lazy dog"),
    "91722dc8d52a3f7b"
  )
end)

test.it("is deterministic", function()
  local input = makeInput(300)
  test.equal(hex64(rapidhash.hash(input)), hex64(rapidhash.hash(input)))
  local empty = hex64(rapidhash.hash(""))
  test.equal(empty, hex64(rapidhash.hash("")))
end)

test.it("hashes binary data with high bits set", function()
  local s = string.char(0x00, 0xff, 0x80, 0x7f, 0x01, 0xfe, 0x00, 0xff, 0x80, 0x7f, 0x01, 0xfe)
  -- known value verified against the C reference (see vectors fixture)
  test.equal(hex64(rapidhash.hash(s)), "4fd63e03631b5936")
  -- a single flipped byte changes the hash
  local s2 = string.char(0x01, 0xff, 0x80, 0x7f, 0x01, 0xfe, 0x00, 0xff, 0x80, 0x7f, 0x01, 0xfe)
  test.notEqual(hex64(rapidhash.hash(s2)), hex64(rapidhash.hash(s)))
end)

test.it("returns distinct hashes for distinct pattern inputs", function()
  local seen = {}
  for len = 0, 200 do
    local h = hex64(rapidhash.hash(makeInput(len)))
    test.falsy(seen[h])
    seen[h] = true
  end
end)

test.it("uses the full 64-bit output, not just the low 32 bits", function()
  -- different seeds must perturb the high 32 bits as well
  local firstHi
  local allEqual = true
  for seed = 1, 64 do
    local hi = tonumber(bit.rshift(rapidhash.hash("rapidhash", seed), 32))
    if firstHi == nil then
      firstHi = hi
    elseif hi ~= firstHi then
      allEqual = false
    end
  end
  test.falsy(allEqual)
end)
