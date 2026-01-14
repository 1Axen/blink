local diagnostics = require("@util/diagnostics")
local span = require("@util/span")

local ast = require("@ast")
local codes = require("@config/codes")
local lexer = require("@compiler/lexer")
local style = require("@util/style")

type Token = lexer.Token
type TokenKind = lexer.TokenKind
export type Entry = ast.Identifier | ast.ExprNumber | ast.ExprString | ast.ExprBoolean

local function report_expect(token: Token, kind: TokenKind): never
	return diagnostics
		.error(codes.parser.UnexpectedToken)
		:with_message(`Expected "{kind}", got "{token.kind}" instead`)
		:with_label(diagnostics.label(token.span):with_message("Here"):with_style(style.color.red))
		:error()
end

local function report_expect_one_of(token: Token, kinds: { TokenKind }): never
	return diagnostics
		.error(codes.parser.UnexpectedToken)
		:with_message(`Expected one of "{table.concat(kinds, '", "')}", got "{token.kind}" instead`)
		:with_label(diagnostics.label(token.span):with_message("Here"):with_style(style.color.red))
		:error()
end

local function report_expect_one_of_ident(span: span.Span, got: string, expected: { string }): never
	return diagnostics
		.error(codes.parser.UnexpectedToken)
		:with_message(`Expected one of "{table.concat(expected, '", "')}", got "{got}" instead`)
		:with_label(diagnostics.label(span):with_message("Here"):with_style(style.color.red))
		:error()
end

local function report_invalid_attribute_placement(stat: ast.Statement): never
	return diagnostics
		.error(codes.parser.SyntaxError)
		:with_message('Expected a "type", "event" or "function" declaration after attribute')
		:with_label(
			diagnostics
				.label(stat.span)
				:with_style(style.color.red)
				:with_message('Expected a "type", "event" or "function" declaration')
		)
		:error()
end

local function report_shadow(caster: ast.Identifier, shaded: ast.Identifier): never
	return diagnostics
		.error(codes.analysis.Shadow)
		:with_message(`"{caster.value}" shadows previous declaration`)
		:with_label(
			diagnostics.label(caster.span):with_style(style.color.red):with_message("Duplicate declaration here")
		)
		:with_label(
			diagnostics.label(shaded.span):with_style(style.color.cyan):with_message("Previously declared here")
		)
		:error()
end

local function report_invalid_range(range: ast.Range): never
	return diagnostics
		.error(codes.analysis.InvalidRange)
		:with_message("Invalid range")
		:with_label(diagnostics.label(range.span):with_style(style.color.red):with_message("Invalid range"))
		:with_note('Ranges must be in the format "min..max"')
		:with_note("Ranges must have a min smaller than or equal to it's max")
		:with_note(
			"Ranges can only be placed on supported built-in values (numerals, strings, buffers, vectors etc.) and arrays"
		)
		:error()
end

local function report_duplicate_entry(expr: ast.Expression, original: Entry, duplicate: Entry): never
	local kind = expr.kind
	return diagnostics
		.error(codes.analysis.DuplicateEntry)
		:with_message(`Duplicate entry "{original.value}" in {kind}`)
		:with_label(diagnostics.label(original.span):with_style(style.color.cyan):with_message(`Original entry`))
		:with_label(diagnostics.label(duplicate.span):with_style(style.color.red):with_message(`Duplicate entry`))
		:with_label(
			diagnostics
				.label(expr.span)
				:with_style(style.color.bright_purple)
				:with_message(`The duplicate entry was found in {style.color.bright_purple("this")} {kind}`)
		)
		:error()
end

local function report_duplicate_entry_early(original: Entry, duplicate: Entry): never
	return diagnostics
		.error(codes.analysis.DuplicateEntry)
		:with_message(`Duplicate entry "{original.value}"`)
		:with_label(diagnostics.label(original.span):with_style(style.color.cyan):with_message(`Original entry`))
		:with_label(diagnostics.label(duplicate.span):with_style(style.color.red):with_message(`Duplicate entry`))
		:error()
end

local function report_missing_entries(struct: span.Span, entries: { string }): never
	return diagnostics
		.error(codes.parser.MissingEntry)
		:with_message(`Expected struct to contain "{table.concat(entries, '", ')}"`)
		:with_label(diagnostics.label(struct):with_style(style.color.red):with_message("Add missing entries to struct"))
		:error()
end

local function report_import_prefix(path: ast.ExprString, prefix: string): never
	return diagnostics
		.error(codes.analysis.InvalidImport)
		:with_message(`Import path should start with one of "@", "." or ".."`)
		:with_label(
			diagnostics.label(path.span):with_style(style.color.red):with_message(`Invalid path prefix: "{prefix}"`)
		)
		:error()
end

local function report_import_extension(path: ast.ExprString, extension: string): never
	return diagnostics
		.error(codes.analysis.InvalidImport)
		:with_message(`Import path shouldn't contain an extension`)
		:with_label(
			diagnostics
				.label(path.span)
				:with_style(style.color.red)
				:with_message(`Remove file extension from path: "{extension}"`)
		)
		:error()
end

local function report_discrminated_union_tag_in_variant(tag: ast.ExprString, field: ast.ExprField)
	return diagnostics
		.error(codes.analysis.ReservedIdentifier)
		:with_message(`Union tag used as field name in variant`)
		:with_label(diagnostics.label(tag.span):with_style(style.color.blue):with_message(`The union tag`))
		:with_label(
			diagnostics.label(field.name.span):with_style(style.color.red):with_message(`Change the field's name`)
		)
		:error()
end

return table.freeze({
	expect = report_expect,
	expect_one_of = report_expect_one_of,
	expect_one_of_ident = report_expect_one_of_ident,

	shadow = report_shadow,
	missing_entries = report_missing_entries,
	duplicate_entry = report_duplicate_entry,
	duplicate_entry_early = report_duplicate_entry_early,

	invalid_range = report_invalid_range,
	invalid_attribute_placement = report_invalid_attribute_placement,

	import_prefix = report_import_prefix,
	import_extension = report_import_extension,

	discrminated_union_tag_in_variant = report_discrminated_union_tag_in_variant,
})
