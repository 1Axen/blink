local symbols = require("@util/symbols")

export type NodeId<T = Node> = number & { __T: T }

export type PathSegment = {
    read span: vector,
    read kind: "segment",
    read value: string,
}

export type Path = {
    read span: vector,
    read kind: "path",
    read segments: {PathSegment}
}

export type Range = {
    read span: vector,
    read kind: "range",
    read min: ExprNumber?,
    read max: ExprNumber?,
}

export type Identifier = {
    read span: vector,
    read kind: "identifier",
    read value: string
}

--- `A = u8` in `<A = u8, B, C>`
export type GenericDef = {
    id: NodeId,
    read span: vector,
    read kind: "generic",

    read name: Identifier,
    read default: Expression?,
}

--- <A = u8, B, C>
export type GenericsDef = {
    id: NodeId,
    read span: vector,
    read kind: "generics",

    read values: { GenericDef }
}

export type GenericsArgs = {
    id: NodeId,
    read span: vector,
    read kind: "generics",

    read values: { Expression }
}

export type ExprNumber = {
    id: NodeId,
    read span: vector,
    read kind: "number",

    read value: number,
}

export type ExprString = {
    id: NodeId,
    read span: vector,
    read kind: "string",

    read value: string,
}

export type ExprBoolean = {
    id: NodeId,
    read span: vector,
    read kind: "boolean",

    read value: boolean
}

--- [name]: value
export type ExprField = {
    id: NodeId,
    read span: vector,
    read kind: "field",

    read name: Identifier,
    read value: Expression,
}

--- set { text }
export type ExprSet = {
    id: NodeId,
    read span: vector,
    read kind: "set",

    read values: { Identifier }
}

--- map {[index]: value}
export type ExprMap = {
    id: NodeId,
    read span: vector,
    read kind: "map",

    index: Expression,
    read value: Expression,
}

export type ExprPackParameter = {
    id: NodeId,
    read span: vector,
    read kind: "parameter",

    read name: Identifier?,
    read value: Expression
}

export type ExprPack = {
    id: NodeId,
    read span: vector,
    read kind: "pack",

    read values: { ExprPackParameter }
}

--- enum { text }
export type ExprEnum = {
    id: NodeId,
    read span: vector,
    read kind: "enum",

    variants: { Identifier }
}

export type ExprArray = {
    id: NodeId,
    read span: vector,
    read kind: "array",

    read value: Expression,
    read range: Range
}

export type ExprOptional = {
    id: NodeId,
    read span: vector,
    read kind: "optional",

    read value: Expression,
}

--- struct { field }
export type ExprStruct = {
    id: NodeId,
    read span: vector,
    read kind: "struct",

    read fields: { ExprField }
}

--- struct & struct
export type ExprUnion = {
    id: NodeId,
    read span: vector,
    read kind: "union",

    read left: Expression,
    read right: Expression
}

--- [name] { ... }
export type ExprTaggedEnumVariant = {
    id: NodeId,
    read span: vector,
    read kind: "variant",

    read name: Identifier | ExprBoolean,
    read value: ExprStruct
}

--- enum [tag] { text }
export type ExprTaggedEnum = {
    id: NodeId,
    read span: vector,
    read kind: "tag_enum",

    read tag: ExprString,
    read variants: { ExprTaggedEnumVariant }
}

--- [path]<[generics]>
export type ExprReference = {
    id: NodeId,
    read span: vector,
    read kind: "reference",

    read path: Path,
    read range: Range?,
    read generics: GenericsArgs?
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
    | ExprReference
;

--- type [name]<Generics> = [value]
export type StatType = {
    id: NodeId,
    read span: vector,
    read kind: "type",

    read name: Identifier,
    read value: Expression,
    read generics: GenericsDef?,

    read export: boolean,
}

export type StatEvent = {
    id: NodeId,
    read span: vector,
    read kind: "event",

    read name: Identifier,
    read from: Identifier,
    read type: Identifier,
    read call: Identifier,
    read poll: ExprBoolean,
    read data: (Expression | ExprPack)?,
}

export type StatScope = {
    id: NodeId,
    read span: vector,
    read kind: "scope",

    read name: Identifier,
    read body: Block,
}

--- import [path]
--- import [path] as [as]
export type StatImport = {
    id: NodeId,
    read span: vector,
    read kind: "import",

    read name: Identifier,
    read path: ExprString,
}

--- option [name] = [value]
export type StatOption = {
    id: NodeId,
    read span: vector,
    read kind: "option",

    read name: Identifier,
    read value: Expression,
}

export type StatFunction = {
    id: NodeId,
    read span: vector,
    read kind: "function",

    read name: Identifier,
    read yield: Identifier,
    read data: (Expression | ExprPack)?,
    read ret: (Expression | ExprPack)?
}

export type Statement =
    | StatType
    | StatEvent
    | StatScope
    | StatImport
    | StatOption
    | StatFunction
;

export type Node = 
    | Statement
    | Expression

export type Block = {
    read kind: "block",
    read statements: {Statement}
}

export type Ast = {
    read kind: "ast",
    read body: Block,
    read symbols: symbols.Symbols<Statement>
}

local fmt_statement;
local fmt_expression;

local function fmt_range(node: Range): string
    local expr_min = node.min
    local expr_max = node.max

    local min = expr_min and tostring(expr_min.value) or ""
    local max = expr_max and tostring(expr_max.value) or ""

    return `({min}..{max})`
end

local function fmt_generic(node: GenericDef): string
    local name = node.name
    if node.default then
        return `{name.value} = {fmt_expression(node.default)}`
    end

    return `{name.value}`
end

local function fmt_generics(node: GenericsDef): string
    local strings = {}
    for _, generic in node.values do
        table.insert(strings, fmt_generic(generic))
    end

    return `<{table.concat(strings, ", ")}>`
end

local function fmt_segment(node: PathSegment): string
    return node.value
end

local function fmt_path(node: Path): string
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
        return `{fmt_expression((expr :: ExprArray).value)}[]`
    elseif expr.kind == "boolean" then
        return tostring((expr :: ExprBoolean).value)
    elseif expr.kind == "optional" then
        return `{fmt_expression((expr :: ExprOptional).value)}?`
    elseif expr.kind == "tag_enum" then
        return `enum "{fmt_expression((expr :: ExprTaggedEnum).tag)}" \{ ... \}`
    elseif expr.kind == "reference" then
        return fmt_path(expr.path)
    end

    error("unreachable")
end

function fmt_statement(stat: Statement): string
    if stat.kind == "type" then
        local name = stat.name
        local generics = stat.generics
        return `{fmt_identifier(name)}{if generics then fmt_generics(generics) else ""}`
    end

    error("unreachable")
end

return table.freeze({
    fmt_path = fmt_path,
    fmt_range = fmt_range,
    fmt_generics = fmt_generics,
    fmt_statement = fmt_statement,
    fmt_expression = fmt_expression,
    fmt_identifier = fmt_identifier,
})