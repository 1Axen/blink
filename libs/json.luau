local RUNTIME = require("@util/runtime")()

local function standalone()
	local json = require("@std/json")

	local function encode<T>(value: T): string
		return json.serialize("json", value)
	end

	local function decode<T>(encoded: buffer | string): T
		return json.deserialize("json", encoded)
	end

	return table.freeze({
		encode = encode,
		decode = decode,
	})
end

local function roblox()
	local HTTP_SERVICE = game:GetService("HttpService")

	local function encode<T>(value: T): string
		return HTTP_SERVICE:JSONEncode(value)
	end

	local function decode<T>(encoded: buffer | string): T
		local input = if typeof(encoded) == "buffer" then buffer.tostring(encoded) else encoded
		return HTTP_SERVICE:JSONDecode(input)
	end

	return table.freeze({
		encode = encode,
		decode = decode,
	})
end

return if RUNTIME == "Standalone" then standalone() else roblox()
