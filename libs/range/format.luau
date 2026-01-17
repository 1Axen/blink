local fmt_types = require("@util/format_types")
local range = require("@util/range")
local style = require("@util/style")

local DOUBLE_DOTS = style.modifer.dim("..")

local function fmt_range(range: range.SealedRange): string
	local components = table.create(3) :: { string }
	if range.min then
		table.insert(components, fmt_types.number(range.min))
	end

	table.insert(components, DOUBLE_DOTS)

	if range.max then
		table.insert(components, fmt_types.number(range.max))
	end

	return table.concat(components)
end

return fmt_range
