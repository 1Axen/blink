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
    read kind: "Uint",
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
    read x: Numeral?,
    read y: Numeral?,
    read z: Numeral?,
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

export type RobloxEnum = {
    read kind: "roblox_enum",
    read type: String?,
}

export type Color3 = {
    read kind: "color3"
}

export type CFrame = {
    read kind: "cframe",
    read position: Numeral?,
    read rotation: Numeral?,
}

export type DateTime = {
    read kind: "datetime",
}

export type DateTimeMillis = {
    read kind: "datetimemillis",
}

export type BrickColor3 = {
    read kind: "brickcolor3",
}

export type Instance = {
    read kind: "instance",
    read class: String?,
}

-- Blink primitives

export type Set = {
    read kind: "set",
    read items: {string}
}

export type Map = {
    read kind: "map",
    read index: TyId,
    read value: TyId
}

export type UnitEnum = {
    read kind: "enum",
    read variants: {string}
}

export type TaggedEnumVariant = {
    read kind: "enum_variant",
    read key: string | boolean,
    read value: GenericDataType<Struct>
}

export type TaggedEnum = {
    read kind: "tagged_enum",
    read tag: string,
    read variants: {string}
}

export type Field = {
    read kind: "field",
    read name: string,
    read value: TyId
}

export type Struct = {
    read kind: "struct",
    read fields: {Field}
}

export type Union = {
    read kind: "union",
    read left: TyId,
    read right: TyId
}

export type GenericDataType<T = Map | Union | Struct | TaggedEnum> = {
    read kind: "GDT",
    read def: TyId<T>,
    read args: {Ty}
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
    | Boolean

export type TyKind = index<Ty, "kind">

return table.freeze({})