local style = require("@util/style")
local range = require("@util/range")
local fmt_types = require("@format/types")

local function fmt_range(range: range.Range): string
    return `({fmt_types.number(range.min)}{style.modifer.dim("..")}{fmt_types.number(range.max)})`
end

return fmt_range