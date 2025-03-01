local symbols = require("@util/symbols")
local builder = require("@util/builder")
local colorful = require("@vendor/colorful")

type Builder = builder.Builder
type Symbols<T> = symbols.Symbols<T>

local function fmt_symbols<T>(symbls: Symbols<T>, previous: Builder?): string
    local fmt_builder = previous or builder.create()
    if previous == nil then
        builder.append_line(fmt_builder, colorful.color.blueBright("<ROOT>"))
        builder.indent(fmt_builder)
    end

    for name in symbls.values do
        builder.append_line(fmt_builder, `- {name}`)
    end

    -- child symbols
    for name, child in symbls.children do
        builder.append_line(fmt_builder, colorful.color.yellow(`@{name}`))
        builder.indent(fmt_builder)
        fmt_symbols(child, fmt_builder)
        builder.dedent(fmt_builder)
    end

    return builder.to_string(fmt_builder)
end

return fmt_symbols