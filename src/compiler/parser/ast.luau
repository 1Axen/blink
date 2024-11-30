local span = require("@util/span")

type Span = span.Span

export type Identifier = {
    span: Span,
    kind: "identifier",
    value: string,
}

export type ExprRange = {
    span: Span,
    kind: "range",
    
    min: ExprNumber?,
    max: ExprNumber?
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
    range: ExprRange
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

--- [name]<[generics]>
export type ExprReference = {
    span: Span,
    kind: "reference",

    name: Identifier,
    range: ExprRange?,
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
    | ExprReference
;

--- type [name]<Generics> = [value]
export type StatType = {
    span: Span,
    kind: "type",

    name: Identifier,
    value: Expression,
    generics: { Identifier },

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

    as: ExprString?,
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

return {}