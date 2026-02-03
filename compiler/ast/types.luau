--!strict

export type NodeKind = index<Node, "kind">
export type StatKind = index<Statement, "kind">
export type ExprKind = index<Expression, "kind">

export type Path = {
	read id: NodeId,
	read span: vector,
	read kind: "path",
	read segments: { Identifier },
}

export type Range = {
	read id: NodeId,
	read span: vector,
	read kind: "range",
	read min: ExprNumber?,
	read max: ExprNumber?,
}

export type Identifier = {
	read id: NodeId,
	read span: vector,
	read kind: "identifier",
	read value: string,
}

--- `A = u8` in `<A = u8, B, C>`
export type GenericDef = {
	read id: NodeId,
	read span: vector,
	read kind: "generic",
	read name: Identifier,
	--read default: Expression?,
}

--- <A = u8, B, C>
export type GenericsDef = {
	read span: vector,
	read kind: "generics",
	read values: { GenericDef },
}

export type GenericsArgs = {
	read span: vector,
	read kind: "generics",
	read values: { Expression },
}

export type ExprNumber = {
	read id: NodeId,
	read span: vector,
	read kind: "number",
	read value: number,
}

export type ExprString = {
	read id: NodeId,
	read span: vector,
	read kind: "string",
	read value: string,
}

export type ExprBoolean = {
	read id: NodeId,
	read span: vector,
	read kind: "boolean",
	read value: boolean,
}

export type ExprLiteral = | ExprNumber | ExprString | ExprBoolean

--- [name]: value
export type ExprField = {
	read id: NodeId,
	read span: vector,
	read kind: "field",
	read name: Identifier | ExprString,
	read value: Expression,
}

--- map {[index]: value}
export type ExprMap = {
	read id: NodeId,
	read span: vector,
	read kind: "map",
	read index: Expression,
	read value: Expression,
	read range: Range?,
}

export type ExprPackParameter = {
	read id: NodeId,
	read span: vector,
	read kind: "parameter",
	read name: Identifier?,
	read value: Expression,
}

--- (expr...)
--- or single expr (syntax sugar)
export type ExprPack = {
	read id: NodeId,
	read span: vector,
	read kind: "pack",
	read values: { ExprPackParameter },
}

export type ExprArray = {
	read id: NodeId,
	read span: vector,
	read kind: "array",
	read value: Expression,
	read range: Range,
}

export type ExprOptional = {
	read id: NodeId,
	read span: vector,
	read kind: "optional",
	read value: Expression,
}

--- struct { field }
export type ExprStruct = {
	read id: NodeId,
	read span: vector,
	read kind: "struct",
	read fields: { ExprField },
}

--- struct & struct
export type ExprUnion = {
	read id: NodeId,
	read span: vector,
	read kind: "union",
	read components: { Expression },
}

--- [name] { ... }
export type ExprDiscriminatedUnionVariant = {
	read id: NodeId,
	read span: vector,
	read kind: "variant",
	read key: | Identifier | ExprNumber | ExprString | ExprBoolean,
	read value: ExprStruct,
}

--- enum [tag] { text }
export type ExprDiscriminatedUnion = {
	read id: NodeId,
	read span: vector,
	read kind: "discriminated_union",
	read tag: ExprString,
	read variants: { ExprDiscriminatedUnionVariant },
}

--- [path]<[generics]>
export type ExprReference = {
	read id: NodeId,
	read span: vector,
	read kind: "reference",
	read path: Path,
	read range: Range?,
	read generics: GenericsArgs?,
}

export type Expression =
	| ExprMap
	| ExprArray
	| ExprUnion
	| ExprStruct
	| ExprField
	| ExprDiscriminatedUnion
	| ExprDiscriminatedUnionVariant
	| ExprNumber
	| ExprString
	| ExprBoolean
	| ExprOptional
	| ExprReference

--- @attr(1, "meow")
export type Attribute = {
	read span: vector,
	read kind: "attribute",
	read name: Identifier,
	read args: { ExprLiteral },
}

--- type [name]<Generics> = [value]
export type StatType = {
	read id: NodeId,
	read span: vector,
	read kind: "type",
	read name: Identifier,
	read value: Expression,
	read generics: GenericsDef?,
	read attributes: { Attribute },
}

export type StatEvent = {
	read id: NodeId,
	read span: vector,
	read kind: "event",
	read attributes: { Attribute },
	read name: Identifier,
	read from: Identifier,
	read type: Identifier,
	read call: Identifier,
	read poll: ExprBoolean?,
	read data: ExprPack?,
}

export type StatScope = {
	read id: NodeId,
	read span: vector,
	read kind: "scope",
	read name: Identifier,
	read body: Block,
}

--- from "path" import *
--- from "path" import * as name
--- from "path" import {A, B, C as D}
export type StatImport = {
	read id: NodeId,
	read span: vector,
	read kind: "import",
	read path: ExprString,

	read extra: {
		read kind: "all",
		--- as name
		read star: Identifier,
		read into_scope: Identifier?,
	} | {
		read kind: "destructured",
		read values: { { path: Path, rename_to: Identifier? } },
	},
}

--- option [name] = [value]
export type StatOption = {
	read id: NodeId,
	read span: vector,
	read kind: "option",
	read name: Identifier,
	read value: ExprLiteral,
}

export type StatFunction = {
	read id: NodeId,
	read span: vector,
	read kind: "function",
	read attributes: { Attribute },
	read name: Identifier,
	read data: ExprPack?,
	read ret: ExprPack?,
}

--stylua: ignore
export type Statement =
    | StatType
    | StatEvent
    | StatScope
    | StatImport
    | StatOption
    | StatFunction

--stylua: ignore
export type Node = 
    | Path
    | Block
    | Range
    | Statement
    | Expression
    | Identifier
    | GenericDef

export type NodeId = number | { write __kind: "node" }

export type Block = {
	read id: NodeId,
	read span: vector,
	read kind: "block",
	read statements: { Statement },
}

export type Ast = {
	read kind: "ast",
	read body: Block,
}

return nil
