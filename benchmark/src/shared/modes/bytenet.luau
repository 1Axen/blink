local ByteNet = require("../../../packages/bytenet")
return ByteNet.defineNamespace("Benchmark", function()
	return {
		Booleans = ByteNet.definePacket({
			value = ByteNet.array(ByteNet.bool),
		}),
		Entities = ByteNet.definePacket({
			value = ByteNet.array(ByteNet.struct({
				id = ByteNet.uint8,
				x = ByteNet.uint8,
				y = ByteNet.uint8,
				z = ByteNet.uint8,
				orientation = ByteNet.uint8,
				animation = ByteNet.uint8,
			})),
		}),
	}
end)
