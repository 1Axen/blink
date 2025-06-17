local panic = require("@util/panic")

--- Panics if passed a variant
local function strong_exhaustive_match(variant: never): never
	return panic(`Unmatched enum variant: {variant}`)
end

return strong_exhaustive_match
