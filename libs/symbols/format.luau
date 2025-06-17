local colorful = require("@vendor/colorful")
local string_builder = require("@util/string_builder")
local symbols = require("@util/symbols")

type StringBuilder = string_builder.StringBuilder
type Symbols<T> = symbols.Symbols<T>

local function fmt_symbols<T>(symbls: Symbols<T>, previous: StringBuilder?): string
	local fmt_builder = previous or string_builder.create()
	if previous == nil then
		string_builder.append_line(fmt_builder, colorful.color.blueBright("<ROOT>"))
		string_builder.indent(fmt_builder)
	end

	for name in symbls.values do
		string_builder.append_line(fmt_builder, `- {name}`)
	end

	-- child symbols
	for name, child in symbls.children do
		string_builder.append_line(fmt_builder, colorful.color.yellow(`@{name}`))
		string_builder.indent(fmt_builder)
		fmt_symbols(child, fmt_builder)
		string_builder.dedent(fmt_builder)
	end

	return string_builder.finalize(fmt_builder)
end

return fmt_symbols
