local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local floor = math.floor
local byte = string.byte

local TWO32 = 4294967296

local rapidSecret = {
	[1] = 0x2d358dccaa6c78a5ULL,
	[2] = 0x8bb84b93962eacc9ULL,
	[3] = 0x4b33a62ed433d4a3ULL,
	[4] = 0x4d5a2da51de1aa47ULL,
	[5] = 0xa0761d6478bd642fULL,
	[6] = 0xe7037ed1a0b428dbULL,
	[7] = 0x90ed1765281c388cULL,
	[8] = 0xaaaaaaaaaaaaaaaaULL
}

---@param n number|ffi.cdata*
local function numToU64(n)
	if n >= 0 and n < TWO32 then
		return 0ULL + n
	end

	local hi = floor(n / TWO32)
	local lo = n - hi * TWO32
	if lo < 0 then
		lo = lo + TWO32
		hi = hi - 1
	end
	if hi < 0 then
		hi = hi + TWO32
	end
	return bor(lshift(0ULL + hi, 32), 0ULL + lo)
end

---@param seed (number|ffi.cdata*)?
local function toU64(seed)
	if type(seed) == "cdata" then
		return seed
	end

	return numToU64(seed or 0)
end

---@param s string
---@param pos number
local function read64le(s, pos)
	local b1, b2, b3, b4, b5, b6, b7, b8 = byte(s, pos, pos + 7)
	local lo = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
	local hi = b5 + b6 * 256 + b7 * 65536 + b8 * 16777216
	return bor(lshift(0ULL + hi, 32), 0ULL + lo)
end

---@param s string
---@param pos number
local function read32le(s, pos)
	local b1, b2, b3, b4 = byte(s, pos, pos + 3)
	return 0ULL + (b1 + b2 * 256 + b3 * 65536 + b4 * 16777216)
end

---64x64 -> 128 bit multiply (port of rapid_mum's portable fallback).
---Returns the low and high 64 bits of the product as cdata.
---@param a number
---@param b number
local function rapidMum(a, b)
	local ha = rshift(a, 32)
	local hb = rshift(b, 32)
	local la = band(a, 0x00000000ffffffffULL)
	local lb = band(b, 0x00000000ffffffffULL)
	local rh = ha * hb
	local rm0 = ha * lb
	local rm1 = hb * la
	local rl = la * lb
	local t = rl + lshift(rm0, 32)

	local c = 0
	if t < rl then c = 1 end

	local lo = t + lshift(rm1, 32)
	if lo < t then c = c + 1 end

	local hi = rh + rshift(rm0, 32) + rshift(rm1, 32) + c
	return lo, hi
end

---@param a number
---@param b number
local function rapidMix(a, b)
	return bxor(rapidMum(a, b))
end

---@param s string  Input buffer.
---@param seed number cdata seed.
---@return number cdata 64-bit hash.
local function rapidHashInternal(s, seed)
	local len = #s
	local i = len

	seed = bxor(seed, rapidMix(bxor(seed, rapidSecret[3]), rapidSecret[2]))

	local a, b = 0ULL, 0ULL

	if len <= 16 then
		if len >= 4 then
			seed = bxor(seed, numToU64(len))
			if len >= 8 then
				a = read64le(s, 1)
				b = read64le(s, len - 7)
			else
				a = read32le(s, 1)
				b = read32le(s, len - 3)
			end
		elseif len > 0 then
			-- a = p[0] << 45 | p[len-1];  b = p[len>>1]
			local first = byte(s, 1)
			local last = byte(s, len)
			local mid = byte(s, floor(len / 2) + 1)
			a = bor(lshift(0ULL + first, 45), 0ULL + last)
			b = 0ULL + mid
		end
	else
		local pos = 1
		if i > 112 then
			local see1, see2, see3, see4, see5, see6 =
				seed, seed, seed, seed, seed, seed

			while i > 112 do
				seed = rapidMix(bxor(read64le(s, pos), rapidSecret[1]), bxor(read64le(s, pos + 8), seed))
				see1 = rapidMix(bxor(read64le(s, pos + 16), rapidSecret[2]), bxor(read64le(s, pos + 24), see1))
				see2 = rapidMix(bxor(read64le(s, pos + 32), rapidSecret[3]), bxor(read64le(s, pos + 40), see2))
				see3 = rapidMix(bxor(read64le(s, pos + 48), rapidSecret[4]), bxor(read64le(s, pos + 56), see3))
				see4 = rapidMix(bxor(read64le(s, pos + 64), rapidSecret[5]), bxor(read64le(s, pos + 72), see4))
				see5 = rapidMix(bxor(read64le(s, pos + 80), rapidSecret[6]), bxor(read64le(s, pos + 88), see5))
				see6 = rapidMix(bxor(read64le(s, pos + 96), rapidSecret[7]), bxor(read64le(s, pos + 104), see6))
				pos = pos + 112
				i = i - 112
			end

			seed = bxor(seed, see1)
			see2 = bxor(see2, see3)
			see4 = bxor(see4, see5)
			seed = bxor(seed, see6)
			see2 = bxor(see2, see4)
			seed = bxor(seed, see2)
		end

		if i > 16 then
			seed = rapidMix(bxor(read64le(s, pos), rapidSecret[3]), bxor(read64le(s, pos + 8), seed))

			if i > 32 then
				seed = rapidMix(bxor(read64le(s, pos + 16), rapidSecret[3]), bxor(read64le(s, pos + 24), seed))

				if i > 48 then
					seed = rapidMix(bxor(read64le(s, pos + 32), rapidSecret[2]), bxor(read64le(s, pos + 40), seed))

					if i > 64 then
						seed = rapidMix(bxor(read64le(s, pos + 48), rapidSecret[2]), bxor(read64le(s, pos + 56), seed))

						if i > 80 then
							seed = rapidMix(bxor(read64le(s, pos + 64), rapidSecret[3]), bxor(read64le(s, pos + 72), seed))

							if i > 96 then
								seed = rapidMix(bxor(read64le(s, pos + 80), rapidSecret[2]), bxor(read64le(s, pos + 88), seed))
							end
						end
					end
				end
			end
		end

		a = bxor(read64le(s, pos + i - 16), numToU64(i))
		b = read64le(s, pos + i - 8)
	end

	a = bxor(a, rapidSecret[2])
	b = bxor(b, seed)

	local lo, hi = rapidMum(a, b)
	return rapidMix(bxor(lo, rapidSecret[8]), bxor(hi, bxor(rapidSecret[2], numToU64(i))))
end

local rapidhash = {}

---@param s string
---@param seed (number|ffi.cdata*)?
function rapidhash.hash(s, seed)
	if seed == nil then
		seed = 0ULL
	else
		seed = toU64(seed)
	end

	return rapidHashInternal(s, seed)
end

---@param s string
---@param seed (number|ffi.cdata*)?
function rapidhash.hex(s, seed)
	local h = rapidhash.hash(s, seed)
	return string.format("%016x", h)
end

return rapidhash
