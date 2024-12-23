local id = require("@compiler/id")
local style = require("@util/style")

local function fmt_id(any_id: id.Id): string
    local kind = id.kind(any_id)
    local unique = bit32.extract(any_id, 0, 30)
    return style.combine(`{kind}<{unique}>`, style.color.purple, style.modifer.dim)
end

return fmt_id