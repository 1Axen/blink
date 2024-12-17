local span = require("@util/span")
local range = require("@util/range")

type Span = span.Span
type Range = range.Range

export type TyId<T = TyKind> = number & { __T: T }
export type IntSize = "8" | "16" | "24" | "32" | "48"
export type UintSize = "8" | "16" | "24" | "32" | "48"
export type FloatSize = "16" | "32" | "64"

-- Luau Primitives

export type Int = {
    read kind: "int",
    read size: IntSize,
    read range: Range?,
}

export type Uint = {
    read kind: "uint",
    read size: UintSize,
    read range: Range?,
}

export type Float = {
    read kind: "float",
    read size: FloatSize,
    read range: Range?,
}

export type Vector = {
    read kind: "vector",
    read x: TyId<Numeral>?,
    read y: TyId<Numeral>?,
    read z: TyId<Numeral>?,
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

-- ROBLOX Datatypes

export type Enum = {
    read kind: "roblox_enum",
    read type: string?,
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
    read class: String?,
}

-- Blink primitives

export type Field = {
    read kind: "field",
    read name: string,
    read value: TyId
}

export type Set = {
    read kind: "set",
    read items: {string}
}

export type Map = {
    read kind: "map",
    read index: TyId,
    read value: TyId
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
    | GenericDataType<Union>
    | GenericDataType<Struct> 
    | Optional<GenericDataType<Union>>
    | Optional<GenericDataType<Struct>> 
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
    read variants: {Field}
}

export type Placeholder = {
    read kind: "placeholder",
    read name: string,
}

export type GenericDataType<T = Map | Union | Struct | TaggedEnum | Placeholder> = {
    read kind: "generic_data_type",
    read def: TyId<T>,
    read args: {TyId}
}

export type Unknown = {
    read kind: "unknown"
}

type Numeral =
    | Int
    | Uint
    | Float

export type Ty =
    | Int
    | Uint
    | Float
    | String
    | Vector
    | Buffer
    | Boolean

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
    | Placeholder
    | GenericDataType
    | Unknown

export type TyKind = index<Ty, "kind">

return table.freeze({})