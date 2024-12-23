local ast = require("@compiler/structures/ast")

local fmt_statement;
local fmt_expression;

local function fmt_range(node: ast.Range): string
    local expr_min = node.min
    local expr_max = node.max

    local min = expr_min and tostring(expr_min.value) or ""
    local max = expr_max and tostring(expr_max.value) or ""

    return `({min}..{max})`
end

local function fmt_generic(node: ast.GenericDef): string
    local name = node.name
    if node.default then
        --return `{name.value} = {fmt_expression(node.default)}`
        return `{name.value}`
    end

    return `{name.value}`
end

local function fmt_generics(node: ast.GenericsDef): string
    local strings = {}
    for _, generic in node.values do
        table.insert(strings, fmt_generic(generic))
    end

    return `<{table.concat(strings, ", ")}>`
end

local function fmt_segment(node: ast.PathSegment): string
    return node.value
end

local function fmt_path(node: ast.Path): string
    local path = ""
    local indices = #node.segments

    for index, segment in node.segments do
        path ..= fmt_segment(segment)
        if index < indices then
            path ..= "."
        end
    end

    return path
end

local function fmt_identifier(node: ast.Identifier): string
    return node.value
end

function fmt_expression(expr: ast.Expression): string
    if expr.kind == "set" then
        return "set { ... }"
    elseif expr.kind == "map" then
        return "map { ... }"
    elseif expr.kind == "enum" then
        return "enum { ... }"
    elseif expr.kind == "union" then
        return `{fmt_expression(expr.left)} & {fmt_expression(expr.right)}`
    elseif expr.kind == "struct" then
        return "struct { ... }"
    elseif expr.kind == "string" then
        return `"{expr.value}"`
    elseif expr.kind == "number" then
        return tostring(expr.value)
    elseif expr.kind == "array" then
        return `{fmt_expression((expr :: ast.ExprArray).value)}[]`
    elseif expr.kind == "boolean" then
        return tostring((expr :: ast.ExprBoolean).value)
    elseif expr.kind == "optional" then
        return `{fmt_expression((expr :: ast.ExprOptional).value)}?`
    elseif expr.kind == "tag_enum" then
        return `enum "{fmt_expression((expr :: ast.ExprTaggedEnum).tag)}" \{ ... \}`
    elseif expr.kind == "reference" then
        return fmt_path(expr.path)
    end

    error("unreachable")
end

function fmt_statement(stat: ast.Statement): string
    if stat.kind == "type" then
        local name = stat.name
        local generics = stat.generics
        return `{fmt_identifier(name)}{if generics then fmt_generics(generics) else ""}`
    end

    error("unreachable")
end

return table.freeze({
    range = fmt_range,
    generic = fmt_generic,
    generics = fmt_generics,
    segment = fmt_segment,
    path = fmt_path,
    identifier = fmt_identifier,
    expression = fmt_expression,
    statement = fmt_statement,
})