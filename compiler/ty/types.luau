--!strict

local ast = require("@ast")
local range = require("@util/range")

type Range = range.Range
type Expression = ast.Expression

--stylua: ignore
export type NumFormat = 
	| "u" 
	| "i" 
	| "f"

--stylua: ignore
export type NumSize = 
	| "8" 
	| "16" 
	| "24" 
	| "32" 
	| "48" 
	| "64"

export type Numeral = {
	read kind: "numeral",
	read node: Expression?,
	read size: NumSize,
	read format: NumFormat,
	read bounds: Range?,
}

--stylua: ignore
export type Axis = 
	| Numeral
	| NumberLiteral

export type Vector = {
	read kind: "vector",
	read node: Expression?,
	read x: Axis?,
	read y: Axis?,
	read z: Axis?,
	read magnitude: Range?,
}

export type Buffer = {
	read kind: "buffer",
	read node: Expression?,
	read length: Range?,
}

export type String = {
	read kind: "string",
	read node: Expression?,
	read length: Range?,
}

export type Nil = {
	read kind: "nil",
	read node: Expression?,
}

export type Boolean = {
	read kind: "boolean",
	read node: Expression?,
}

export type StringLiteral = {
	read kind: "string_literal",
	read node: Expression?,
	read value: string,
}

export type NumberLiteral = {
	read kind: "number_literal",
	read node: Expression?,
	read value: number,
}

export type BooleanLiteral = {
	read kind: "boolean_literal",
	read node: Expression?,
	read value: boolean,
}

--stylua: ignore
export type Literal = 
	| StringLiteral 
	| NumberLiteral 
	| BooleanLiteral

export type Enum = {
	read kind: "roblox_enum",
	read node: Expression?,
	read type: StringLiteral?,
}

export type Color3 = {
	read kind: "color3",
	read node: Expression?,
}

export type CFrame = {
	read kind: "cframe",
	read node: Expression?,
	read position: Numeral?,
	read rotation: Numeral?,
}

export type DateTime = {
	read kind: "date_time",
	read node: Expression?,
}

export type DateTimeMillis = {
	read kind: "date_time_millis",
	read node: Expression?,
}

export type BrickColor = {
	read kind: "brick_color",
	read node: Expression?,
}

export type Instance = {
	read kind: "instance",
	read node: Expression?,
	read class: StringLiteral?,
}

export type Map = {
	read kind: "map",
	read node: Expression?,
	read size: Range?,
	read index: Ty,
	read value: Ty,
}

export type Field = {
	read kind: "field",
	read node: Expression?,
	read name: string,
	read value: Ty,
}

export type Struct = {
	read kind: "struct",
	read node: Expression?,
	read fields: { Field },
}

export type Array = {
	read kind: "array",
	read node: Expression?,
	read of: Ty,
	read size: Range?,
}

export type Union = {
	read kind: "union",
	read node: Expression?,
	read components: { Ty },
}

export type Variant = {
	read kind: "variant",
	read node: Expression?,
	read key: Literal,
	read value: Struct,
}

export type DiscriminatedUnion = {
	read kind: "discriminated_union",
	read node: Expression?,
	read tag: string,
	read variants: { Variant },
}

export type Unknown = {
	read kind: "unknown",
	read node: Expression?,
}

export type Blocked = {
	read kind: "blocked",
	read node: Expression?,
}

export type Generic = {
	read kind: "generic",
	read node: Expression?,
	read name: string,
	read index: number,
}

export type Reference = {
	read kind: "reference",
	read node: Expression?,
	read to: TyId,
	read arguments: { Ty }?,
}

export type TypeFunction = {
	read kind: "type_function",
	read node: Expression?,
	read body: Ty,
	read parameters: { Generic },
}

export type TypeInstantiation = {
	read kind: "type_instantiation",
	read node: Expression?,
	read type_function: TyId<TypeFunction>,
	read arguments: { Ty },
	body: Ty,
}

--stylua: ignore
export type Ty =
    | Numeral
    | String
    | Vector
    | Buffer
    | Boolean
	| Nil

    | StringLiteral
    | NumberLiteral
    | BooleanLiteral

    | Enum
    | CFrame
    | Color3
    | Instance
    | BrickColor
    | DateTime
    | DateTimeMillis

    | Map
    | Array
    | Struct
    | Union
    | DiscriminatedUnion
    | Unknown

	| Blocked
    | Generic
	| Reference
    | TypeFunction
	| TypeInstantiation

export type TyId<T = Ty> = number | { write __kind: "ty", write __T: T }
export type TyKind = index<Ty, "kind">

return nil
