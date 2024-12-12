--!strict
--!native
--!optimize 2

local ast = require("@compiler/parser/ast")
local codes = require("@compiler/config/codes")
local options = require("@compiler/config/options")
local primitives = require("@compiler/config/primitives")

local span = require("@util/span")
local range = require("@util/range")
local symbols = require("@util/symbols")
local diagnostics = require("@util/diagnostics")

type Range = range.Range
type Symbols = symbols.Symbols<ast.Statement>

export type Analyser = {
    symbols: Symbols,
    warn_on_option: true?,
}

local ROOT_SYMBOLS = ""

local block: (analyser: Analyser, block: ast.Block, name: string) -> ();
local statement: (analyser: Analyser, statement: ast.Statement) -> ();
local expression: (analyser: Analyser, expression: ast.Expression) -> ();

local function unwrap(expr: ast.Expression): ast.Expression
    if expr.kind == "optional" then
        return expr.value
    end

    return expr
end

local function report_shadow(analyser: Analyser, caster: ast.Identifier, shaded: ast.Identifier): never
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

local function report_optional(analyser: Analyser, optional: ast.ExprOptional): never
    return diagnostics.report.create("Error")
        .with_code(codes.analysis.OptionalInMap)
        .with_message("Optionals cannot be used in maps")
        .with_label(diagnostics.label.create(optional.span)
            .with_color(diagnostics.style.color.red)
            .with_message("Remove optional value")
        )
    .finish()
    .error()
end

local function report_invalid_range(analyser: Analyser, range: ast.Range): never
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

type Entry = {span: span.Span, value: any}

local function report_duplicate_entry(analyser: Analyser, expr: ast.Expression, original: Entry, duplicate: Entry): never
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

local function report_unknown_reference(analyser: Analyser, expr: ast.ExprReference): never
    local name = expr.name
    return diagnostics.report.create("Error")
        .with_code(codes.analysis.UnknownReference)
        .with_message(`Unknown reference "{name.value}"`)
        .with_label(diagnostics.label.create(name.span)
            .with_color(diagnostics.style.color.red)
            .with_message(`Unknown reference`)
        )
    .finish()
    .error()
end

local function report_unrepresentable_range(analyser: Analyser, number: ast.ExprNumber, range: Range): never
    return diagnostics.report.create("Error")
        .with_code(codes.analysis.UnrepresentableRange)
        .with_message("Unrepresentable range")
        .with_label(diagnostics.label.create(number.span)
            .with_color(diagnostics.style.color.red)
            .with_message("Number outside type range bounds")
        )
        .with_note(`Type range bounds: ({range.min}..{range.max})`)
    .finish()
    .error()
end

--- Gets the expression/global referenced in `expr`
--- Errors if no expression/global can be found
local function deref(analyser: Analyser, ref: ast.ExprReference): ast.StatType
    local name = ref.name
    local stat = symbols.search(analyser.symbols, name.value)

    if stat == nil or stat.kind ~= "type" then
        return report_unknown_reference(analyser, ref)
    end

    return stat
end

--- Gets the expression/global referenced in `expr` recursively
--- Errors if no expression/global can be found
local function deref_deep(analyser: Analyser, expr: ast.ExprReference): ast.StatType
    local node = expr
    while true do
        local stat = deref(analyser, node)
        local value = stat.value

        if value.kind == "reference" then
            node = value
            continue
        end

        return stat
    end

    error("unreachable")
end

local function assert_no_shadow(analyser: Analyser, name: ast.Identifier): never?
    local existing = symbols.search(analyser.symbols, name.value)
    if existing ~= nil then
        return report_shadow(analyser, name, existing.name)
    end

    return
end

local function validate_generics(analyser: Analyser, expr: ast.ExprReference, stat: ast.StatType): never?
    local generics = stat.generics
    if generics == nil then
        return
    end

    local name = expr.name
    local maximum = #generics.values
    local required = 0

    for _, generic in generics.values do
        if generic.default == nil then
            required += 1
        end
    end
    
    local specified = expr.generics and #expr.generics or 0
    if specified < required or specified > maximum then
        local label_message = if specified > maximum then "Remove extra arguments" else "Add missing arguments"
        local stat_str = "?"
        
        if stat then
            stat_str = ast.fmt_statement(stat)
        end

        return diagnostics.report.create("Error")
            .with_code(codes.analysis.GenericsParameters)
            .with_message(`Generic type "{stat_str}" expects {required} argument(s), but {specified} are specifed`)
            .with_label(diagnostics.label.create(name.span)
                .with_color(diagnostics.style.color.red)
                .with_message(label_message)
            )
        .finish()
        .error()
    end

    return
end

local function validate_range(analyser: Analyser, range: ast.Range, bounds: Range): never?
    local min = range.min
    local max = range.max

    local bounds_min = bounds.min
    local bounds_max = bounds.max
    
    local min_value = min and min.value or bounds.min
    local max_value = max and max.value or bounds.max

    if min_value > max_value then
        return report_invalid_range(analyser, range)
    end

    if min and (min_value < bounds_min or min_value > bounds_max) then
        return report_unrepresentable_range(analyser, min, bounds) 
    end

    if max and (max_value < bounds_min or max_value > bounds_max) then
        return report_unrepresentable_range(analyser, max, bounds) 
    end

    return
end

local function expr_primitive(analyser: Analyser, expr: ast.ExprPrimitive): never?
    local name = expr.name
    local primitive = primitives[name.value]

    print(name.value, primitive, expr.generics)

    --> generics
    local generics = expr.generics
    if generics then
        local expected = primitive.generics or 0
        local specified = #generics

        if specified > expected then
            local label_message = if specified > expected then "Remove extra arguments" else "Add missing arguments"
            return diagnostics.report.create("Error")
                .with_code(codes.analysis.GenericsParameters)
                .with_message(`Primitive type "{name.value}" expects {expected} argument(s), but {specified} are specifed`)
                .with_label(diagnostics.label.create(expr.span)
                    .with_color(diagnostics.style.color.red)
                    .with_message(label_message)
                )
            .finish()
            .error()
        end
    end

    --> range
    local range = expr.range
    if range then
        local bounds = primitive.range
        if bounds == nil then
            return report_invalid_range(analyser, range)
        end

        validate_range(analyser, range, bounds)
    end

    return
end

local function expr_reference(analyser: Analyser, expr: ast.ExprReference): never?
    local stat = deref(analyser, expr)
    
    --> generics
    validate_generics(analyser, expr, stat)
    
    return
end

local function expr_set(analyser: Analyser, expr: ast.ExprSet): never?
    local entries: {[string]: ast.Identifier} = {}
    for _, entry in expr.values do
        local previous = entries[entry.value]
        if previous then
            return report_duplicate_entry(analyser, expr, previous, entry)
        end

        entries[entry.value] = entry
    end

    return
end

local function expr_map(analyser: Analyser, expr: ast.ExprMap)
    local index: ast.Expression = expr.index
    local value: ast.Expression = expr.value

    if index.kind == "reference" then
        local stat = deref_deep(analyser, index)
        index = stat.value
    end

    if value.kind == "reference" then
        local stat = deref_deep(analyser, value)
        value = stat.value
    end

    if index.kind == "optional" then
        report_optional(analyser, index)
    elseif value.kind == "optional" then
        report_optional(analyser, value)
    end

    expression(analyser, index)
    expression(analyser, value)
end

local function expr_pack(analyser: Analyser, expr: ast.ExprPack)
    for _, value in expr.values do
        expression(analyser, value.value)
    end
end

local function expr_enum(analyser: Analyser, expr: ast.ExprEnum): never?
    local variants: {[string]: ast.Identifier} = {}
    for _, variant in expr.variants do
        local value = variant.value
        local previous = variants[value]
        if previous ~= nil then
            return report_duplicate_entry(analyser, expr, previous, variant)
        end

        variants[value] = variant
    end

    return
end

local function expr_struct(analyser: Analyser, expr: ast.ExprStruct): never?
    local fields: {[string]: ast.Identifier} = {}
    for _, field in expr.fields do
        local name = field.name
        local value = name.value
        local previous = fields[value]

        if previous ~= nil then
            return report_duplicate_entry(analyser, expr, previous, name)
        end

        fields[value] = name
        expression(analyser, field.value)
    end

    return
end

local function expr_union(analyser: Analyser, expr: ast.ExprUnion): never?
    local function validate_side(side: ast.Expression): boolean?
        --> unwrap
        side = unwrap(side)

        if side.kind == "union" then
            expr_union(analyser, side)
            return true
        elseif side.kind == "reference" then
            --> prevent smuggling non structs through references
            local stat = deref_deep(analyser, side)
            side = unwrap(stat.value)
        elseif side.kind == "struct" then
            --> validate struct
            expr_struct(analyser, side)
        end

        return (side.kind == "struct")
    end

    if 
        validate_side(expr.left) == false 
        or validate_side(expr.right) == false 
    then
        return diagnostics.report.create("Error")
            .with_code(codes.analysis.InvalidUnion)
            .with_message(`Unable to union "{expr.left.kind}" and "{expr.right.kind}"`)
            .with_label(diagnostics.label.create(expr.span)
                .with_color(diagnostics.style.color.bright_red)
                .with_message("Make sure both values are structs")
            )
        .finish()
        .error()   
    end

    return
end

local function expr_array(analyser: Analyser, expr: ast.ExprArray)
    expression(analyser, expr.value)
end

local function expr_tag_enum(analyser: Analyser, expr: ast.ExprTaggedEnum): never?
    local variants: {[string]: ast.Identifier | ast.ExprBoolean} = {}
    for _, variant in expr.variants do
        local name = variant.name
        local str_name = tostring(name.value)

        local previous = variants[str_name]
        if previous ~= nil then
            return report_duplicate_entry(analyser, expr, previous, name)
        end

        variants[str_name] = name
        expr_struct(analyser, variant.value)
    end

    return
end

local function expr_pack_or_single(analyser: Analyser, expr: ast.Expression | ast.ExprPack)
    if expr.kind == "pack" then
        expr_pack(analyser, expr)
    else
        expression(analyser, expr)
    end
end

local function stat_type(analyser: Analyser, stat: ast.StatType)
    local name = stat.name
    local primitive = primitives[name.value]
    if primitive ~= nil then
        diagnostics.report.create("Error")
            .with_code(codes.analysis.ReservedIdentifier)
            .with_message(`Cannot use reserved identifier "{name.value}"`)
            .with_label(diagnostics.label.create(name.span)
                .with_color(diagnostics.style.color.red)
                .with_message(`Change identifier`)
            )
        .finish()
        .error()
    end

    expression(analyser, stat.value)
end

local function stat_event(analyser: Analyser, stat: ast.StatEvent)
    local data = stat.data
    if data ~= nil then
        expr_pack_or_single(analyser, data)
    end
end

local function stat_option(analyser: Analyser, stat: ast.StatOption): never?
    if analyser.warn_on_option then
        diagnostics.report.create("Warning")
            .with_message("Option will be ignored because it is after the first non option statement")
            .with_label(diagnostics.label.create(stat.span)
                .with_message("Move this")
                .with_color(diagnostics.style.color.cyan)
            )
        .finish()
        .print()
    end

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

    local raw_value = ast.value_of_expr(value)
    if opt_config.values and table.find(opt_config.values, raw_value) == nil then
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

    return
end

local function stat_function(analyser: Analyser, stat: ast.StatFunction)
    local data = stat.data
    if data ~= nil then
        expr_pack_or_single(analyser, data)
    end

    local ret = stat.ret
    if ret ~= nil then
        expr_pack_or_single(analyser, ret)
    end
end

function expression(analyser: Analyser, expr: ast.Expression)
    if expr.kind == "map" then
        expr_map(analyser, expr)
    elseif expr.kind == "set" then
        expr_set(analyser, expr)
    elseif expr.kind == "array" then
        expr_array(analyser, expr)
    elseif expr.kind == "enum" then
        expr_enum(analyser, expr)
    elseif expr.kind == "struct" then
        expr_struct(analyser, expr)
    elseif expr.kind == "union" then
        expr_union(analyser, expr)
    elseif expr.kind == "tag_enum" then
        expr_tag_enum(analyser, expr)
    elseif expr.kind == "optional" then
        expression(analyser, expr.value)
    elseif expr.kind == "reference" then
        expr_reference(analyser, expr)
    elseif expr.kind == "primitive" then
        expr_primitive(analyser, expr)
    end
end

function statement(analyser: Analyser, stat: ast.Statement)
    local name = stat.name
    if stat.kind == "type" then
        stat_type(analyser, stat)
    elseif stat.kind == "event" then
        stat_event(analyser, stat)
    elseif stat.kind == "scope" then
        block(analyser, stat.block, stat.name.value)
    elseif stat.kind == "option" then
        stat_option(analyser, stat)
    elseif stat.kind == "function" then
        stat_function(analyser, stat)
    end

    if stat.kind ~= "option" then
        analyser.warn_on_option = true
    end

    assert_no_shadow(analyser, name)
    symbols.set(analyser.symbols, name.value, stat)
end

function block(analyser: Analyser, block: ast.Block, name: string)
    --> inner symbols
    local parent = analyser.symbols
    analyser.symbols = symbols.inner(parent, name)

    for _, stat in block.statements do
        statement(analyser, stat)
    end

    --> restore symbols
    analyser.symbols = parent
end

local function analyse(ast: ast.Ast)
    local analyser: Analyser = {
        symbols = symbols.create(ROOT_SYMBOLS),
    }

    block(analyser, ast.block, ROOT_SYMBOLS)
end

return table.freeze({
    analyse = analyse
})