--!strict
--!native
--!optimize 2

--[[
MIT License

Copyright (c) 2023-2024 Micah Reid

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

--- Precomputed MD5 constants. You may compute these manually
--- with `floor(2^32 * abs(sin(i + 1)))` from 0 to 63.
--stylua: ignore
local K = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
}

--- The order in which lrotates happen in the core loops.
--stylua: ignore
local SHIFT_ORDER = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
}

--- An allocation that is reused for blocks in the compression function.
local BLOCK = table.create(64) :: {number}

--- Processes `message` from byte `start` to byte `finish` using `digest`.
--- It is assumed that `(finish - start) % 64 == 0`.
local function processBlocks(digest: { number }, message: string, start: number, finish: number)
	local block = BLOCK
	local d1, d2, d3, d4 = digest[1], digest[2], digest[3], digest[4]

	for i = start, finish, 64 do
		-- Fill `block`
		for t = 1, 16 do
			-- But what if I were to simply construct an integer in reverse
			-- order? Oh hoho! Delightfully devilish, Seymour!
			local d, c, b, a = string.byte(message, i, i + 3)
			block[t] = bit32.bor(bit32.lshift(a, 24), bit32.lshift(b, 16), bit32.lshift(c, 8), d)
			i += 4
		end

		-- Standard MD5 rounds. It's quite a bit faster if these are unrolled,
		-- but I don't want to. This module is already very fast.
		local a, b, c, d = d1, d2, d3, d4
		local d_temp, func = 0, 0
		for j = 0, 15 do
			func = bit32.bxor(d, bit32.band(b, bit32.bxor(c, d)))
			d_temp = d
			d = c
			c = b
			b = b + bit32.lrotate(a + func + K[j + 1] + block[j + 1], SHIFT_ORDER[j + 1])
			a = d_temp
		end

		for j = 16, 31 do
			func = bit32.bxor(c, bit32.band(d, bit32.bxor(b, c)))
			d_temp = d
			d = c
			c = b
			b = b + bit32.lrotate(a + func + K[j + 1] + block[(5 * j + 1) % 16 + 1], SHIFT_ORDER[j + 1])
			a = d_temp
		end

		for j = 32, 47 do
			func = bit32.bxor(b, c, d)
			d_temp = d
			d = c
			c = b
			b = b + bit32.lrotate(a + func + K[j + 1] + block[(3 * j + 5) % 16 + 1], SHIFT_ORDER[j + 1])
			a = d_temp
		end

		for j = 48, 63 do
			func = bit32.bxor(c, bit32.bor(b, bit32.bnot(d)))
			d_temp = d
			d = c
			c = b
			b = b + bit32.lrotate(a + func + K[j + 1] + block[(7 * j) % 16 + 1], SHIFT_ORDER[j + 1])
			a = d_temp
		end

		d1 = bit32.bor(a + d1)
		d2 = bit32.bor(b + d2)
		d3 = bit32.bor(c + d3)
		d4 = bit32.bor(d + d4)
	end

	digest[1] = d1
	digest[2] = d2
	digest[3] = d3
	digest[4] = d4
end

--[=[
	Computes the MD5 hash for `message` and returns it.
	The function returns both a hexadecimal encoded string of the hash
	and a **read-only** table containing the four 32-bit integers that
	make the hash up.

	@param message -- The payload to compute the MD5 hash of.
	@return string -- The computed MD5 hash as a string of hexadecimal digits
	@return {number} -- The computed MD5 hash as a read-only array of 4 integers
]=]
local function md5(message: string): (string, { number })
	local digest = {
		0x67452301,
		0xefcdab89,
		0x98badcfe,
		0x10325476,
	}

	local messageLen = #message
	local leftover = messageLen % 64
	if messageLen >= 64 then
		processBlocks(digest, message, 1, messageLen - leftover)
	end

	-- Raise `leftover` to next multiple of 64 so that we can calculate
	-- how much padding we need without a branch or loop.
	-- The number here is just masking off the last 6 bits.
	local nextMultipleOf64 = bit32.band(leftover + 32, 0xffffffc0)

	local finalMessage = {
		if leftover ~= 0 then string.sub(message, -leftover) else "",
		"\x80",
		string.rep("\0", (nextMultipleOf64 - leftover - 9) % 64),
		string.pack("<L", messageLen * 8),
	}
	local finalBlock = table.concat(finalMessage)
	processBlocks(digest, finalBlock, 1, #finalBlock)

	digest[1] = bit32.byteswap(digest[1])
	digest[2] = bit32.byteswap(digest[2])
	digest[3] = bit32.byteswap(digest[3])
	digest[4] = bit32.byteswap(digest[4])

	return string.format("%08x%08x%08x%08x", digest[1], digest[2], digest[3], digest[4]), table.freeze(digest)
end

return md5