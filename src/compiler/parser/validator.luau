--!strict
--!native
--!optimize 2

local ast = require("@compiler/ast")
local codes = require("@compiler/config/codes")
local options = require("@compiler/config/options")
local primitives = require("@compiler/config/primitives")

local range = require("@util/range")
local symbols = require("@util/symbols")
local diagnostics = require("@util/diagnostics")

type Ast = ast.Ast
type Range = range.Range
type Literal = string | number | boolean
export type Symbols = symbols.Symbols<ast.Statement>

type Validator = {
    symbols: Symbols
}

local block: (validator: Validator, block: ast.Block, name: string) -> ();
local statement: (validator: Validator, statement: ast.Statement) -> ();
local expression: (validator: Validator, expression: ast.Expression) -> ();

local function as_literal(expr: ast.Expression): Literal | never
    if expr.kind == "string" then
        return expr.value :: string
    elseif expr.kind == "number" then
        return expr.value :: number
    elseif expr.kind == "boolean" then
        return expr.value :: boolean
    end

    return diagnostics.report.create("Error")
        .with_message(`Expected one of string, number, boolean; got "{expr.kind}" instead`)
        .with_label(diagnostics.label.create((expr :: ast.Expression).span)
            .with_color(diagnostics.style.color.red)
            .with_message("Expected one of string, number, boolean")
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

type Entry = ast.Identifier | ast.ExprString | ast.ExprBoolean

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

local function expr_range(validator: Validator, range: ast.Range): ast.Range
    local min = range.min
    local max = range.max

    local max_value = max and max.value or 0
    local min_value = min and min.value or max_value

    if min_value > max_value then
        return report_invalid_range(range)
    end

    return range
end

local function expr_reference(validator: Validator, expr: ast.ExprReference): never?
    local range = expr.range
    local generics = expr.generics
    
    if generics then
        for index, generic in generics.values do
            expression(validator, generic)
        end
    end

    if range then
        range = expr_range(validator, range)
    end

    return nil
end

local function expr_set(validator: Validator, expr: ast.ExprSet): never?
    local entries: {[string]: ast.Identifier} = {}
    for _, entry in expr.values do
        local previous = entries[entry.value]
        if previous then
            return report_duplicate_entry(expr, previous :: Entry, entry)
        end

        entries[entry.value] = entry
    end

    return nil
end

local function expr_map(validator: Validator, expr: ast.ExprMap): never?
    expression(validator, expr.index)
    expression(validator, expr.value)
    return nil
end

local function expr_pack(validator: Validator, expr: ast.ExprPack): never?
    for _, value in expr.values do
        expression(validator, value.value)
    end

    return nil
end

local function expr_enum(validator: Validator, expr: ast.ExprEnum): never?
    local variants: {[string]: ast.Identifier} = {}
    for _, variant in expr.variants do
        local value = variant.value
        local previous = variants[value]
        if previous ~= nil then
            return report_duplicate_entry(expr, previous, variant)
        end

        variants[value] = variant
    end

    return nil
end

local function expr_struct(validator: Validator, expr: ast.ExprStruct): never?
    local fields: {[string]: ast.Identifier} = {}
    for _, field in expr.fields do
        local name = field.name
        local value = name.value
        local previous = fields[value]

        if previous ~= nil then
            return report_duplicate_entry(expr, previous, name)
        end

        fields[value] = name
        expression(validator, field.value)
    end

    return nil
end

local function expr_union(validator: Validator, expr: ast.ExprUnion)
    expression(validator, expr.left)
    expression(validator, expr.right)
end

local function expr_array(validator: Validator, expr: ast.ExprArray)
    expression(validator, expr.value)
end

local function expr_optional(validator: Validator, expr: ast.ExprOptional)
    expression(validator, expr.value)
end

local function expr_tag_enum(validator: Validator, expr: ast.ExprTaggedEnum): never?
    local variants: {[string]: ast.Identifier | ast.ExprBoolean} = {}
    for _, variant in expr.variants do
        local name = variant.name
        local str_name = tostring(name.value)

        local previous = variants[str_name]
        if previous ~= nil then
            return report_duplicate_entry(expr, previous, name)
        end

        variants[str_name] = name
        expr_struct(validator, variant.value)
    end

    return nil
end

local function expr_pack_or_single(validator: Validator, expr: ast.Expression | ast.ExprPack)
    if expr.kind == "pack" then
        expr_pack(validator, expr)
    else
        expression(validator, expr)
    end
end

local function stat_type(validator: Validator, stat: ast.StatType): never?
    local name = stat.name
    local value = stat.value
    local primitive = primitives[name.value]

    if primitive ~= nil then
        return diagnostics.report.create("Error")
            .with_code(codes.analysis.ReservedIdentifier)
            .with_message(`Cannot use reserved identifier "{name.value}"`)
            .with_label(diagnostics.label.create(name.span)
                .with_color(diagnostics.style.color.red)
                .with_message(`Change identifier`)
            )
        .finish()
        .error()
    end

    --> replace expression if needed (resolved reference)
    expression(validator, value)

    return nil
end

local function stat_event(validator: Validator, stat: ast.StatEvent)
    local data = stat.data
    if data ~= nil then
        expr_pack_or_single(validator, data)
    end
end

local function stat_option(validator: Validator, stat: ast.StatOption): never?
    local name = stat.name
    local value = stat.value

    local opt_config = options[name.value]
    if opt_config == nil then
        return diagnostics.report.create("Error")
            .with_code(codes.analysis.UnknownOption)
            .with_message(`Unknown option "{name}"`)
            .with_label(diagnostics.label.create(name.span)
                .with_color(diagnostics.style.color.red)
                .with_message(`"{name}" is not a valid option`)
            )
        .finish()
        .error()
    end

    if value.kind ~= opt_config.kind then
        return diagnostics.report.create("Error")
            .with_code(codes.analysis.InvalidOption)
            .with_message(`Option "{name}" expects a value of kind "{opt_config.kind}"`)
            .with_label(diagnostics.label.create(value.span)
                .with_color(diagnostics.style.color.red)
                .with_message(`Expected a value of kind "{opt_config.kind}", got "{value.kind}" instead`)
            )
        .finish()
        .error()
    end

    local literal = as_literal(value)
    if opt_config.values and table.find(opt_config.values, literal) == nil then
        local possible_values = `"{table.concat(opt_config.values, "\", ")}"`
        return diagnostics.report.create("Error")
            .with_code(codes.analysis.InvalidOption)
            .with_message(`Option "{name}" expects one of {possible_values}`)
            .with_label(diagnostics.label.create(value.span)
                .with_color(diagnostics.style.color.red)
                .with_message(`Replace with one of {possible_values}`)
            )
        .finish()
        .error()
    end

    return nil
end

local function stat_function(validator: Validator, stat: ast.StatFunction)
    local data = stat.data
    if data ~= nil then
        expr_pack_or_single(validator, data)
    end

    local ret = stat.ret
    if ret ~= nil then
        expr_pack_or_single(validator, ret)
    end
end

function expression(validator: Validator, expr: ast.Expression)
    if expr.kind == "map" then
        expr_map(validator, expr)
    elseif expr.kind == "set" then
        expr_set(validator, expr)
    elseif expr.kind == "array" then
        expr_array(validator, expr)
    elseif expr.kind == "enum" then
        expr_enum(validator, expr)
    elseif expr.kind == "struct" then
        expr_struct(validator, expr)
    elseif expr.kind == "union" then
        expr_union(validator, expr)
    elseif expr.kind == "tag_enum" then
        expr_tag_enum(validator, expr)
    elseif expr.kind == "optional" then
        expr_optional(validator, expr)
    elseif expr.kind == "reference" then
        expr_reference(validator, expr :: ast.ExprReference)
    end
end

function statement(validator: Validator, stat: ast.Statement)
    local name = stat.name
    if stat.kind == "type" then
        stat_type(validator, stat)
    elseif stat.kind == "event" then
        stat_event(validator, stat)
    elseif stat.kind == "scope" then
        block(validator, stat.body, stat.name.value)
    elseif stat.kind == "option" then
        stat_option(validator, stat)
    elseif stat.kind == "function" then
        stat_function(validator, stat)
    end

    local existing = symbols.search(validator.symbols, {name.value})
    if existing ~= nil then
        report_shadow(name, existing.name)
    end

    symbols.set(validator.symbols, name.value, stat)
end

function block(validator: Validator, block: ast.Block, name: string?)
    --> inner symbols
    local parent = validator.symbols
    if name then
        validator.symbols = symbols.inner(parent, name)
    end

    for _, stat in block.statements do
        statement(validator, stat)
    end

    --> restore symbols
    validator.symbols = parent
end

local function validate(ast: Ast)
    local validator: Validator = {
        symbols = ast.symbols
    }

    block(validator, ast.body)
end

return table.freeze({
    validate = validate
})