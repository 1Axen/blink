local id = require("@compiler/id")
local style = require("@util/style")

local KIND_STYLE = style.combine(style.color.bright_blue)
local UNIQUE_STYLE = style.combine(style.color.blue, style.modifer.dim)

local function fmt_id(any_id: id.Id): string
    local kind = id.kind(any_id)
    local file = id.file(any_id)
    local index = id.index(any_id)
    return `{KIND_STYLE(kind)}{UNIQUE_STYLE(string.format("(%03i:%03i)", file, index))}`
end

return fmt_id