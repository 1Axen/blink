--!strict

local symbols = require("@util/symbols")

export type NodeId<T = Node> = number & { __kind: "node", __T: T }

export type NodeKind = index<Node, "kind">
export type StatKind = index<Statement, "kind">
export type ExprKind = index<Expression, "kind">

export type Symbols = symbols.Symbols<Statement>

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
    --read default: Expression?,
}

--- <A = u8, B, C>
export type GenericsDef = {
    read span: vector,
    read kind: "generics",
    read values: { GenericDef }
}

export type GenericsArgs = {
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

    read index: Expression,
    read value: Expression,
    read range: Range?,
}

export type ExprPackParameter = {
    id: NodeId,
    read span: vector,
    read kind: "parameter",

    read name: Identifier?,
    read value: Expression
}

--- (expr...)
--- or single expr (syntax sugar)
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

    read key: 
        | Identifier 
        | ExprNumber 
        | ExprString 
        | ExprBoolean,
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
    read poll: ExprBoolean?,
    read data: ExprPack?,
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
    read data: ExprPack?,
    read ret: ExprPack?
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
    | GenericDef

export type Block = {
    read kind: "block",
    read statements: {Statement}
}

export type Ast = {
    read kind: "ast",
    read body: Block,
    read symbols: Symbols
}

local DUMMY_ID = -1

return table.freeze({
    DUMMY_ID = DUMMY_ID
})