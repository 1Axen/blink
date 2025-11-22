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

-- luau types

export type Numeral = {
	read kind: "numeral",
	read size: NumSize,
	read format: NumFormat,
	read bounds: Range?,
}

--stylua: ignore
export type Axis = 
	| TyId<Numeral> 
	| TyId<NumberLiteral>

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

export type Boolean = {
	read kind: "boolean",
}

-- Luau Literals

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
export type Literal = | StringLiteral | NumberLiteral | BooleanLiteral

-- roblox types

export type Enum = {
	read kind: "roblox_enum",
	read type: TyId<StringLiteral>?,
}

export type Color3 = {
	read kind: "color3",
}

export type CFrame = {
	read kind: "cframe",
	read position: TyId<Numeral>?,
	read rotation: TyId<Numeral>?,
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
	read class: TyId<StringLiteral>?,
}

-- blink types

export type Map = {
	read kind: "map",
	read size: Range?,
	read index: TyId,
	read value: TyId,
}

export type Field = {
	read kind: "field",
	read name: string,
	read value: TyId,
}

export type Struct = {
	read kind: "struct",
	read fields: { Field },
}

export type Array = {
	read kind: "array",
	read of: TyId,
	read size: Range?,
}

--stylua: ignore
export type Union = {
	read kind: "union",
	read components: {TyId}
}

export type Optional = {
	read kind: "optional",
	read of: TyId,
}

export type UnitEnum = {
	read kind: "unit_enum",
	read variants: { TyId<Literal> },
}

export type Variant = {
	read kind: "variant",
	read key: TyId<Literal>,
	read value: Struct,
}

export type TaggedEnum = {
	read kind: "tagged_enum",
	read tag: string,
	read variants: { Variant },
}

export type Unknown = {
	read kind: "unknown",
}

-- compiler types

export type Generic = {
	read kind: "generic",
	read name: string,
	read index: number,
}

--- Represents a type which hasn't been initialized yet
export type Placeholder = {
	read kind: "placeholder",
}

export type Reference = {
	read kind: "reference",
	read to: TyId,
	read args: { TyId }?,
}

export type GenericType = {
	read kind: "generic_type",
	read body: TyId,
	read args: { TyId },
}

--stylua: ignore
export type Ty =
    | Numeral
    | String
    | Vector
    | Buffer
    | Boolean

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
    | Optional
    | UnitEnum
    | TaggedEnum
    | Union
    | Unknown

    | Generic
	| Reference
    | GenericType
    | Placeholder

export type TyId<T = Ty> = number | { write __kind: "ty", write __T: T }
export type TyKind = index<Ty, "kind">

return nil
