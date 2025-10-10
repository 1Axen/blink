local id = require("@compiler/id")
local style = require("@util/style")

local UNIQUE_STYLE = style.combine(style.color.blue, style.modifer.dim)

local function fmt_id(any_id: id.Id): string
	local file = id.file(any_id)
	local index = id.index(any_id)
	return `{UNIQUE_STYLE(string.format("(%03i:%03i)", file, index))}`
end

return fmt_id
