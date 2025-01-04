local span = require("@util/span")
local diagnostics = require("@util/diagnostics")

local ast = require("@compiler/structures/ast")
local codes = require("@compiler/config/codes")
local lexer = require("@compiler/lexer")

type Token = lexer.Token
type TokenKind = lexer.TokenKind
export type Entry = ast.Identifier | ast.ExprNumber | ast.ExprString | ast.ExprBoolean

local function report_expect(token: Token, kind: TokenKind): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.UnexpectedToken)
        .with_message(`Expected "{kind}", got "{token.kind}" instead`)
        .with_label(diagnostics.label.create(token.span)
            .with_message("Here")
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_expect_one_of(token: Token, kinds: {TokenKind}): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.UnexpectedToken)
        .with_message(`Expected one of "{table.concat(kinds, "\", \"")}", got "{token.kind}" instead`)
        .with_label(diagnostics.label.create(token.span)
            .with_message("Here")
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_expect_one_of_ident(span: span.Span, got: string, expected: {string}): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.UnexpectedToken)
        .with_message(`Expected one of "{table.concat(expected, "\", \"")}", got "{got}" instead`)
        .with_label(diagnostics.label.create(span)
            .with_message("Here")
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_invalid_attribute_placement(stat: ast.Statement): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.SyntaxError)
        .with_message('Expected a "type", "event" or "function" declaration after attribute')
        .with_label(diagnostics.label.create(stat.span)
            .with_color(diagnostics.style.color.red)
            .with_message('Expected a "type", "event" or "function" declaration')
        )
    .finish()
    .error()
end

local function report_shadow(caster: ast.Identifier, shaded: ast.Identifier): never
    return diagnostics.report.create("Error")
        .with_code(codes.analysis.Shadow)
        .with_message(`"{caster.value}" shadows previous declaration`)
        .with_label(diagnostics.label.create(caster.span)
            .with_color(diagnostics.style.color.red)
            .with_message("Duplicate declaration here")
        )
        .with_label(diagnostics.label.create(shaded.span)
            .with_color(diagnostics.style.color.cyan)
            .with_message("Previously declared here")
        )
    .finish()
    .error()
end

local function report_invalid_range(range: ast.Range): never
    return diagnostics.report.create("Error")
        .with_code(codes.analysis.InvalidRange)
        .with_message("Invalid range")
        .with_label(diagnostics.label.create(range.span)
            .with_color(diagnostics.style.color.red)
            .with_message("Invalid range")
        )
        .with_note("Ranges must be in the format \"min..max\"")
        .with_note("Ranges must have a min smaller than or equal to it's max")
        .with_note("Ranges can only be placed on supported built-in values (numerals, strings, buffers, vectors etc.) and arrays")
    .finish()
    .error()
end

local function report_duplicate_entry(expr: ast.Expression, original: Entry, duplicate: Entry): never
    local kind = expr.kind
    return diagnostics.report.create("Error")
        .with_code(codes.analysis.DuplicateEntry)
        .with_message(`Duplicate entry "{original.value}" in {kind}`)
        .with_label(diagnostics.label.create(original.span)
            .with_color(diagnostics.style.color.cyan)
            .with_message(`Original entry`)
        )
        .with_label(diagnostics.label.create(duplicate.span)
            .with_color(diagnostics.style.color.red)
            .with_message(`Duplicate entry`)
        )
        .with_label(diagnostics.label.create(expr.span)
            .with_color(diagnostics.style.color.bright_purple)
            .with_message(`The duplicate entry was found in {diagnostics.style.color.bright_purple("this")} {kind}`)
        )
    .finish()
    .error()
end

local function report_duplicate_entry_early(original: Entry, duplicate: Entry): never
    return diagnostics.report.create("Error")
        .with_code(codes.analysis.DuplicateEntry)
        .with_message(`Duplicate entry "{original.value}"`)
        .with_label(diagnostics.label.create(original.span)
            .with_color(diagnostics.style.color.cyan)
            .with_message(`Original entry`)
        )
        .with_label(diagnostics.label.create(duplicate.span)
            .with_color(diagnostics.style.color.red)
            .with_message(`Duplicate entry`)
        )
    .finish()
    .error()
end

local function report_missing_entries(struct: span.Span, entries: {string}): never
    return diagnostics.report.create("Error")
        .with_code(codes.parser.MissingEntry)
        .with_message(`Expected struct to contain "{table.concat(entries, "\", ")}"`)
        .with_label(diagnostics.label.create(struct)
            .with_color(diagnostics.style.color.red)
            .with_message("Add missing entries to struct")
        )
        .finish()
        .error()
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
})