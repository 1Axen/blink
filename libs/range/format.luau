local fmt_types = require("@util/format_types")
local range = require("@util/range")
local style = require("@util/style")

local function fmt_range(range: range.Range): string
	if range.min == range.max then
		return `({fmt_types.number(range.min)})`
	end

	return `({fmt_types.number(range.min)}{style.modifer.dim("..")}{fmt_types.number(range.max)})`
end

return fmt_range
