local id = require("@compiler/id")
local style = require("@util/style")

local KIND_STYLE = style.combine(style.color.bright_blue)
local UNIQUE_STYLE = style.combine(style.color.blue, style.modifer.dim)

local function fmt_id(any_id: id.Id): string
    local kind = id.kind(any_id)
    local unique = bit32.extract(any_id, 0, 30)
    return `{KIND_STYLE(kind)}{UNIQUE_STYLE(string.format("(%03i)", unique))}`
end

return fmt_id