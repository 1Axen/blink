--!strict

local panic = require("@util/panic")
local range = require("@util/range")

type Range = range.Range

export type NumFormat = "u" | "i" | "f"
export type NumSize = "8" | "16" | "24" | "32" | "48" | "64"

-- luau types

export type Numeral = {
	read kind: "numeral",
	read size: NumSize,
	read format: NumFormat,
	read bounds: Range?,
}

local function create_numeral(size: NumSize, format: NumFormat, bounds: Range?): Numeral
	return {
		kind = "numeral",
		size = size,
		format = format,
	}
end

export type Axis = | TyId<Numeral> | TyId<NumberLiteral>

export type Vector = {
	read kind: "vector",
	read x: Axis?,
	read y: Axis?,
	read z: Axis?,
	read magnitude: Range?,
}

--- `axes` is an array of 0-3 TyIds (Numeral or NumberLiteral) corresponding to: x, y, z; in that order
local function create_vector(axes: { Axis }, magnitude: Range?): Vector
	return {
		kind = "vector",
		x = axes[1],
		y = axes[2],
		z = axes[3],
		magnitude = magnitude,
	}
end

export type Buffer = {
	read kind: "buffer",
	read length: Range?,
}

local function create_buffer(length: Range?): Buffer
	return {
		kind = "buffer",
		length = length,
	}
end

export type String = {
	read kind: "string",
	read length: Range?,
}

local function create_string(length: Range?): String
	return {
		kind = "string",
		length = length,
	}
end

export type Boolean = {
	read kind: "boolean",
}

local function create_boolean(): Boolean
	return {
		kind = "boolean",
	}
end

-- Luau Literals

export type StringLiteral = {
	read kind: "string_literal",
	read value: string,
}

local function create_string_literal(value: string): StringLiteral
	return {
		kind = "string_literal",
		value = value,
	}
end

export type NumberLiteral = {
	read kind: "number_literal",
	read value: number,
}

local function create_number_literal(value: number): NumberLiteral
	return {
		kind = "number_literal",
		value = value,
	}
end

export type BooleanLiteral = {
	read kind: "boolean_literal",
	read value: boolean,
}

local function create_boolean_literal(value: boolean): BooleanLiteral
	return {
		kind = "boolean_literal",
		value = value,
	}
end

export type Literal = | StringLiteral | NumberLiteral | BooleanLiteral

local function create_literal(value: index<Literal, "value">): Literal
	if type(value) == "string" then
		return create_string_literal(value)
	elseif type(value) == "number" then
		return create_number_literal(value)
	elseif type(value) == "boolean" then
		return create_boolean_literal(value)
	end

	return panic(`Unable to create literal from value of type "{type(value)}"`)
end

-- roblox types

export type Enum = {
	read kind: "roblox_enum",
	read type: TyId<StringLiteral>?,
}

local function create_roblox_enum(type: TyId<StringLiteral>?): Enum
	return {
		kind = "roblox_enum",
		type = type,
	}
end

export type Color3 = {
	read kind: "color3",
}

local function create_color3(): Color3
	return {
		kind = "color3",
	}
end

export type CFrame = {
	read kind: "cframe",
	read position: TyId<Numeral>?,
	read rotation: TyId<Numeral>?,
}

local function create_cframe(position: TyId<Numeral>, rotation: TyId<Numeral>): CFrame
	return {
		kind = "cframe",
		position = position,
		rotation = rotation,
	}
end

export type DateTime = {
	read kind: "date_time",
}

local function create_date_time(): DateTime
	return {
		kind = "date_time",
	}
end

export type DateTimeMillis = {
	read kind: "date_time_millis",
}

local function create_date_time_millis(): DateTimeMillis
	return {
		kind = "date_time_millis",
	}
end

export type BrickColor = {
	read kind: "brick_color",
}

local function create_brick_color(): BrickColor
	return {
		kind = "brick_color",
	}
end

export type Instance = {
	read kind: "instance",
	read class: TyId<StringLiteral>?,
}

local function create_instance(class: TyId<StringLiteral>?): Instance
	return {
		kind = "instance",
		class = class,
	}
end

-- blink types

export type Map = {
	read kind: "map",
	read size: Range?,
	read index: TyId,
	read value: TyId,
}

local function create_map(index: TyId, value: TyId, size: Range?): Map
	return {
		kind = "map",
		size = size,
		index = index,
		value = value,
	}
end

export type Field = {
	read kind: "field",
	read name: string,
	read value: TyId,
}

local function create_field(name: string, value: TyId): Field
	return {
		kind = "field",
		name = name,
		value = value,
	}
end

export type Struct = {
	read kind: "struct",
	read fields: { Field },
}

local function create_struct(fields: { Field }): Struct
	return {
		kind = "struct",
		fields = fields,
	}
end

export type Array = {
	read kind: "array",
	read of: TyId,
	read size: Range?,
}

local function create_array(of: TyId, size: Range?): Array
	return {
		kind = "array",
		of = of,
		size = size,
	}
end

--stylua: ignore
export type UnionSide = 
	| Union
	| Struct 
	| Optional 
	| GenericType 

export type Union = {
	read kind: "union",
	read left: TyId<UnionSide>,
	read right: TyId<UnionSide>,
}

local function create_union(left: TyId<UnionSide>, right: TyId<UnionSide>): Union
	return {
		kind = "union",
		left = left,
		right = right,
	}
end

export type Optional = {
	read kind: "optional",
	read of: TyId,
}

local function create_optional(of: TyId): Optional
	return {
		kind = "optional",
		of = of,
	}
end

export type UnitEnum = {
	read kind: "unit_enum",
	read variants: { TyId<Literal> },
}

local function create_unit_enum(variants: { TyId<Literal> }): UnitEnum
	return {
		kind = "unit_enum",
		variants = variants,
	}
end

export type Variant = {
	read kind: "variant",
	read key: TyId<Literal>,
	read value: Struct,
}

local function create_variant(key: TyId<Literal>, value: Struct): Variant
	return {
		kind = "variant",
		key = key,
		value = value,
	}
end

export type TaggedEnum = {
	read kind: "tagged_enum",
	read tag: string,
	read variants: { Variant },
}

local function create_tagged_enum(tag: string, variants: { Variant }): TaggedEnum
	return {
		kind = "tagged_enum",
		tag = tag,
		variants = variants,
	}
end

export type Unknown = {
	read kind: "unknown",
}

local function create_unknown(): Unknown
	return {
		kind = "unknown",
	}
end

-- compiler types

export type Generic = {
	read kind: "generic",
	read name: string,
	read index: number,
}

local function create_generic(name: string, index: number): Generic
	return {
		kind = "generic",
		name = name,
		index = index,
	}
end

--- Represents a type which hasn't been initialized yet
export type Placeholder = {
	read kind: "placeholder",
}

local function create_placeholder(): Placeholder
	return { kind = "placeholder" }
end

export type Reference = {
	read kind: "reference",
	read to: TyId,
	read args: { TyId }?,
}

local function create_reference(to: TyId, args: { TyId }?): Reference
	return { kind = "reference", to = to, args = args }
end

export type GenericType = {
	read kind: "generic_type",
	read body: TyId,
	read args: { TyId },
}

local function create_generic_type(body: TyId, args: { TyId }): GenericType
	return {
		kind = "generic_type",
		body = body,
		args = args,
	}
end

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

local RECURSIVE_TYS: { [TyKind]: boolean } = {
	map = true,
	array = true,
	struct = true,
	tagged_enum = true,
	generic_type = true,
}

local function is_possibly_recursive(ty: Ty): boolean
	return RECURSIVE_TYS[ty.kind] or false
end

return table.freeze({
	numeral = create_numeral,
	string = create_string,
	vector = create_vector,
	buffer = create_buffer,
	boolean = create_boolean,

	literal = create_literal,
	string_literal = create_string_literal,
	number_literal = create_number_literal,
	boolean_literal = create_boolean_literal,

	roblox_enum = create_roblox_enum,
	cframe = create_cframe,
	color3 = create_color3,
	instance = create_instance,
	brick_color = create_brick_color,
	date_time = create_date_time,
	date_time_millis = create_date_time_millis,

	map = create_map,
	array = create_array,
	struct = create_struct,
	optional = create_optional,
	unit_enum = create_unit_enum,
	tagged_enum = create_tagged_enum,
	union = create_union,
	unknown = create_unknown,

	generic = create_generic,
	reference = create_reference,
	generic_type = create_generic_type,
	placeholder = create_placeholder,

	field = create_field,
	variant = create_variant,

	is_possibly_recursive = is_possibly_recursive,
})
