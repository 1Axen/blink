--!strict

local range = require("@util/range")

type Range = range.Range

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
	read x: Axis?,
	read y: Axis?,
	read z: Axis?,
	read magnitude: Range?,
}

export type Buffer = {
	read kind: "buffer",
	read length: Range?,
}

export type String = {
	read kind: "string",
	read length: Range?,
}

export type Nil = {
	read kind: "nil",
}

export type Boolean = {
	read kind: "boolean",
}

export type StringLiteral = {
	read kind: "string_literal",
	read value: string,
}

export type NumberLiteral = {
	read kind: "number_literal",
	read value: number,
}

export type BooleanLiteral = {
	read kind: "boolean_literal",
	read value: boolean,
}

--stylua: ignore
export type Literal = 
	| StringLiteral 
	| NumberLiteral 
	| BooleanLiteral

export type Enum = {
	read kind: "roblox_enum",
	read type: StringLiteral?,
}

export type Color3 = {
	read kind: "color3",
}

export type CFrame = {
	read kind: "cframe",
	read position: Numeral?,
	read rotation: Numeral?,
}

export type DateTime = {
	read kind: "date_time",
}

export type DateTimeMillis = {
	read kind: "date_time_millis",
}

export type BrickColor = {
	read kind: "brick_color",
}

export type Instance = {
	read kind: "instance",
	read class: StringLiteral?,
}

export type Map = {
	read kind: "map",
	read size: Range?,
	read index: Ty,
	read value: Ty,
}

export type Field = {
	read kind: "field",
	read name: string,
	read value: Ty,
}

export type Struct = {
	read kind: "struct",
	read fields: { Field },
}

export type Array = {
	read kind: "array",
	read of: Ty,
	read size: Range?,
}

export type Union = {
	read kind: "union",
	read components: { Ty },
}

export type Variant = {
	read kind: "variant",
	read key: Literal,
	read value: Struct,
}

export type DiscriminatedUnion = {
	read kind: "discriminated_union",
	read tag: string,
	read variants: { Variant },
}

export type Unknown = {
	read kind: "unknown",
}

export type Blocked = {
	read kind: "blocked",
}

export type Generic = {
	read kind: "generic",
	read name: string,
	read index: number,
}

export type Reference = {
	read kind: "reference",
	read to: TyId,
	read arguments: { Ty }?,
}

export type TypeFunction = {
	read kind: "type_function",
	read body: Ty,
	read parameters: { Generic },
}

export type TypeInstantiation = {
	read kind: "type_instantiation",
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
