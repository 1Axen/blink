--!strict

local span = require("@util/span")
local range = require("@util/range")

type Span = span.Span
type Range = range.Range

export type TyId<T = TyKind> = number & { __kind: "ty", __T: T }

export type NumFormat = "u" | "i" | "f"
export type NumSize = "8" | "16" | "24" | "32" | "48" | "64"

-- Luau Primitives

export type Numeral = {
    read kind: "numeral",
    read size: NumSize,
    read format: NumFormat,
    read bounds: Range?,
}

export type Vector = {
    read kind: "vector",
    read x: TyId<Numeral | NumberLiteral>?,
    read y: TyId<Numeral | NumberLiteral>?,
    read z: TyId<Numeral | NumberLiteral>?,
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
    read kind: "boolean"
}

-- Luau Literals

export type StringLiteral = {
    read kind: "string_literal",
    read value: string
}

export type NumberLiteral = {
    read kind: "number_literal",
    read value: number
}

export type BooleanLiteral = {
    read kind: "boolean_literal",
    read value: boolean
}

-- ROBLOX Datatypes

export type Enum = {
    read kind: "roblox_enum",
    read type: TyId<StringLiteral>?,
}

export type Color3 = {
    read kind: "color3"
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

-- Blink primitives

export type Field = {
    read kind: "field",
    read name: string,
    read value: TyId
}

export type Variant = {
    read kind: "variant",
    read key: number | string | boolean,
    read value: Struct
}

export type Set = {
    read kind: "set",
    read items: {string}
}

export type Map = {
    read kind: "map",
    read index: TyId,
    read value: TyId,
    read range: Range?
}

export type Struct = {
    read kind: "struct",
    read fields: {Field}
}

export type Array<T = Ty> = {
    read kind: "array",
    read of: TyId<T>,
    read size: Range
}

type UnionSide = TyId<
    | GenericType<Union>
    | GenericType<Struct> 
    | Optional<GenericType<Union>>
    | Optional<GenericType<Struct>> 
>

export type Union = {
    read kind: "union",
    read left: UnionSide,
    read right: UnionSide
}

export type Optional<T = Ty> = {
    read kind: "optional",
    read of: TyId<T>,
}

export type UnitEnum = {
    read kind: "enum",
    read variants: {string}
}

export type TaggedEnum = {
    read kind: "tagged_enum",
    read tag: string,
    read variants: {Variant}
}

export type Generic = {
    read kind: "generic",
    read name: string,
    read index: number,
}

--- Represents a variable which hasn't been typed yet
export type Placeholder = {
    read kind: "placeholder",
    read path: string,
    read args: {TyId}?
}

export type GenericType<T = Ty> = {
    read kind: "generic_type",
    read ty: T,
    read args: {TyId}
}

export type Unknown = {
    read kind: "unknown"
}

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

    | Set
    | Map
    | Array
    | Struct
    | Optional
    | UnitEnum
    | TaggedEnum
    | Generic
    | GenericType
    | Unknown

export type TyKind = index<Ty, "kind">

return table.freeze({})