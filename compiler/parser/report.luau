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

local function report_duplicate_entry(original: Entry, duplicate: Entry): never
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
		:with_message(`Expected fields "{table.concat(entries, '", ')}"`)
		:with_label(diagnostics.label(struct):with_style(style.color.red):with_message("Add missing fields"))
		:error()
end

return table.freeze({
	expect = report_expect,
	expect_one_of = report_expect_one_of,
	expect_one_of_ident = report_expect_one_of_ident,

	shadow = report_shadow,
	missing_entries = report_missing_entries,
	duplicate_entry = report_duplicate_entry,

	invalid_attribute_placement = report_invalid_attribute_placement,
})
