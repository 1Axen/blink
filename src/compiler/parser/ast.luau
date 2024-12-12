local span = require("@util/span")

type Span = span.Span

export type Range = {
    span: Span,
    kind: "range",
    min: ExprNumber?,
    max: ExprNumber?,
}

export type Identifier = {
    span: Span,
    kind: "identifier",
    value: string,
}

--- A in <A = u8, B, C>
export type Generic = {
    span: Span,
    kind: "generic",

    name: Identifier,
    default: Expression?,
}

--- <A = u8, B, C>
export type Generics = {
    span: Span,
    kind: "generics",
    values: {Generic}
}

export type ExprNumber = {
    span: Span,
    kind: "number",
    value: number,
}

export type ExprString = {
    span: Span,
    kind: "string",
    value: string,
}

export type ExprBoolean = {
    span: Span,
    kind: "boolean",
    value: boolean
}

--- [name]: value
export type ExprField = {
    span: Span,
    kind: "field",
    name: Identifier,
    value: Expression,
}

--- set { text }
export type ExprSet = {
    span: Span,
    kind: "set",
    values: { Identifier }
}

--- map {[index]: value}
export type ExprMap = {
    span: Span,
    kind: "map",
    index: Expression,
    value: Expression,
}

export type ExprPackParameter = {
    span: Span,
    kind: "parameter",

    name: Identifier?,
    value: Expression
}

export type ExprPack = {
    span: Span,
    kind: "pack",
    values: { ExprPackParameter }
}

--- enum { text }
export type ExprEnum = {
    span: Span,
    kind: "enum",
    variants: { Identifier }
}

export type ExprArray = {
    span: Span,
    kind: "array",
    value: Expression,
    range: Range
}

export type ExprOptional = {
    span: Span,
    kind: "optional",
    value: Expression,
}

--- struct { field }
export type ExprStruct = {
    span: Span,
    kind: "struct",
    fields: { ExprField }
}

--- struct & struct
export type ExprUnion = {
    span: Span,
    kind: "union",

    left: Expression,
    right: Expression
}

--- [name] { ... }
export type ExprTaggedEnumVariant = {
    span: Span,
    kind: "variant",

    name: Identifier | ExprBoolean,
    value: ExprStruct
}

--- enum [tag] { text }
export type ExprTaggedEnum = {
    span: Span,
    kind: "tag_enum",

    tag: ExprString,
    variants: { ExprTaggedEnumVariant }
}

--- [u8/CFrame/vector]<[generics]>([range])
export type ExprPrimitive = {
    span: Span,
    kind: "primitive",

    name: Identifier,
    range: Range?,
    generics: { Expression }
}

--- [name]<[generics]>
export type ExprReference = {
    span: Span,
    kind: "reference",

    name: Identifier,
    generics: { Expression }
}

export type Expression =
    | ExprSet
    | ExprMap
    | ExprEnum
    | ExprArray
    | ExprUnion
    | ExprStruct
    | ExprTaggedEnum
    | ExprNumber
    | ExprString
    | ExprBoolean
    | ExprOptional
    | ExprPrimitive
    | ExprReference
;

--- type [name]<Generics> = [value]
export type StatType = {
    span: Span,
    kind: "type",

    name: Identifier,
    value: Expression,
    generics: Generics?,

    export: boolean,
}

export type StatEvent = {
    span: Span,
    kind: "event",

    name: Identifier,
    from: Identifier,
    type: Identifier,
    call: Identifier,
    poll: ExprBoolean,
    data: (Expression | ExprPack)?,
}

export type StatScope = {
    span: Span,
    kind: "scope",

    name: Identifier,
    block: Block,
}

--- import [path]
--- import [path] as [as]
export type StatImport = {
    span: Span,
    kind: "import",

    name: Identifier,
    path: ExprString,
}

--- option [name] = [value]
export type StatOption = {
    span: Span,
    kind: "option",

    name: Identifier,
    value: Expression,
}

export type StatFunction = {
    span: Span,
    kind: "function",

    name: Identifier,
    yield: Identifier,
    data: (Expression | ExprPack)?,
    ret: (Expression | ExprPack)?
}

export type Statement =
    | StatType
    | StatEvent
    | StatScope
    | StatImport
    | StatOption
    | StatFunction
;

export type Block = {
    kind: "block",
    statements: {Statement}
}

export type Ast = {
    kind: "ast",
    block: Block,
}

local fmt_statement;
local fmt_expression;

local function value_of_expr(expr: Expression): ...unknown
    if expr.kind == "array" then
        return expr.value
    elseif expr.kind == "set" then
        return expr.values
    elseif expr.kind == "map" then
        return expr.value
    elseif expr.kind == "enum" then
        return expr.variants
    elseif expr.kind == "union" then
        return expr.left, expr.right
    elseif expr.kind == "string" then
        return expr.value
    elseif expr.kind == "optional" then
        return expr.value
    elseif expr.kind == "struct" then
        return expr.fields
    elseif expr.kind == "boolean" then
        return expr.value
    elseif expr.kind == "number" then
        return expr.value
    elseif expr.kind == "reference" then
        return expr.name
    elseif expr.kind == "tag_enum" then
        return expr.variants
    end

    return expr
end

local function fmt_range(node: Range): string
    local expr_min = node.min
    local expr_max = node.max

    local min = expr_min and tostring(expr_min.value) or ""
    local max = expr_max and tostring(expr_max.value) or ""

    return `({min}..{max})`
end

local function fmt_generic(node: Generic): string
    local name = node.name
    if node.default then
        return `{name.value} = {fmt_expression(node.default)}`
    end

    return `{name.value}`
end

local function fmt_generics(node: Generics): string
    local strings = {}
    for _, generic in node.values do
        table.insert(strings, fmt_generic(generic))
    end

    return `<{table.concat(strings, ", ")}>`
end

local function fmt_identifier(node: Identifier): string
    return node.value
end

function fmt_expression(expr: Expression): string
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
        return `{fmt_expression(expr.value)}[]`
    elseif expr.kind == "boolean" then
        return tostring(expr.value)
    elseif expr.kind == "optional" then
        return `{fmt_expression(expr.value)}?`
    elseif expr.kind == "tag_enum" then
        return `enum "{fmt_expression(expr.tag)}" \{ ... \}`
    elseif expr.kind == "primitive" then
        return fmt_identifier(expr.name)
    elseif expr.kind == "reference" then
        return fmt_identifier(expr.name)
    end

    error("unreachable")
end

function fmt_statement(stat: Statement): string
    if stat.kind == "type" then
        local name = stat.name
        local generics = stat.generics
        return `{name.value}{if generics then fmt_generics(generics) else ""}`
    end

    error("unreachable")
end

return table.freeze({
    value_of_expr = value_of_expr,
    fmt_range = fmt_range,
    fmt_generics = fmt_generics,
    fmt_statement = fmt_statement,
    fmt_expression = fmt_expression,
    fmt_identifier = fmt_identifier,
})