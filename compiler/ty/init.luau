--!strict

local format = require("@self/format")
local panic = require("@util/panic")
local range = require("@util/range")
local types = require("@self/types")

type Range = range.Range

export type NumSize = types.NumSize
export type NumFormat = types.NumFormat
export type Numeral = types.Numeral
export type Axis = types.Axis
export type Vector = types.Vector
export type Buffer = types.Buffer
export type String = types.String
export type Boolean = types.Boolean
export type Nil = types.Nil
export type StringLiteral = types.StringLiteral
export type NumberLiteral = types.NumberLiteral
export type BooleanLiteral = types.BooleanLiteral
export type Literal = types.Literal
export type Enum = types.Enum
export type CFrame = types.CFrame
export type DateTime = types.DateTime
export type Color3 = types.Color3
export type DateTimeMillis = types.DateTimeMillis
export type BrickColor = types.BrickColor
export type Instance = types.Instance
export type Map = types.Map
export type Field = types.Field
export type Struct = types.Struct
export type Union = types.Union
export type Array = types.Array
export type Variant = types.Variant
export type Unknown = types.Unknown
export type Blocked = types.Blocked
export type Generic = types.Generic
export type Reference = types.Reference
export type TypeFunction = types.TypeFunction
export type TypeInstantiation = types.TypeInstantiation
export type DiscriminatedUnion = types.DiscriminatedUnion

local function create_numeral(size: NumSize, format: NumFormat, bounds: Range?): Numeral
	return {
		kind = "numeral",
		size = size,
		format = format,
	}
end

--- `axes` is an array of 0-3 TyIds (Numeral or NumberLiteral) corresponding to: x, y, z; in that order
local function create_vector(axes: { Axis? }, magnitude: Range?): Vector
	return {
		kind = "vector",
		x = axes[1],
		y = axes[2],
		z = axes[3],
		magnitude = magnitude,
	}
end

local function create_buffer(length: Range?): Buffer
	return {
		kind = "buffer",
		length = length,
	}
end

local function create_string(length: Range?): String
	return {
		kind = "string",
		length = length,
	}
end

local function create_boolean(): Boolean
	return {
		kind = "boolean",
	}
end

local function create_nil(): Nil
	return {
		kind = "nil",
	}
end

local function create_string_literal(value: string): StringLiteral
	return {
		kind = "string_literal",
		value = value,
	}
end

local function create_number_literal(value: number): NumberLiteral
	return {
		kind = "number_literal",
		value = value,
	}
end

local function create_boolean_literal(value: boolean): BooleanLiteral
	return {
		kind = "boolean_literal",
		value = value,
	}
end

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

local function create_roblox_enum(type: StringLiteral?): Enum
	return {
		kind = "roblox_enum",
		type = type,
	}
end

local function create_color3(): Color3
	return {
		kind = "color3",
	}
end

local function create_cframe(position: Numeral?, rotation: Numeral?): CFrame
	return {
		kind = "cframe",
		position = position,
		rotation = rotation,
	}
end

local function create_date_time(): DateTime
	return {
		kind = "date_time",
	}
end

local function create_date_time_millis(): DateTimeMillis
	return {
		kind = "date_time_millis",
	}
end

local function create_brick_color(): BrickColor
	return {
		kind = "brick_color",
	}
end

local function create_instance(class: StringLiteral?): Instance
	return {
		kind = "instance",
		class = class,
	}
end

local function create_map(index: Ty, value: Ty, size: Range?): Map
	return {
		kind = "map",
		size = size,
		index = index,
		value = value,
	}
end

local function create_field(name: string, value: Ty): Field
	return {
		kind = "field",
		name = name,
		value = value,
	}
end

local function create_struct(fields: { Field }): Struct
	return {
		kind = "struct",
		fields = fields,
	}
end

local function create_array(of: Ty, size: Range?): Array
	return {
		kind = "array",
		of = of,
		size = size,
	}
end

local function create_union(components: { Ty }): Union
	return {
		kind = "union",
		components = components,
	}
end

local function create_variant(key: Literal, value: Struct): Variant
	return {
		kind = "variant",
		key = key,
		value = value,
	}
end

local function create_discriminated_union(tag: string, variants: { Variant }): DiscriminatedUnion
	return {
		kind = "discriminated_union",
		tag = tag,
		variants = variants,
	}
end

local function create_unknown(): Unknown
	return {
		kind = "unknown",
	}
end

local function create_blocked(): Blocked
	return {
		kind = "blocked",
	}
end

local function create_generic(name: string, index: number): Generic
	return {
		kind = "generic",
		name = name,
		index = index,
	}
end

local function create_reference(to: TyId, arguments: { Ty }?): Reference
	return { kind = "reference", to = to, arguments = arguments }
end

local function create_type_function(body: Ty, parameters: { Generic }): TypeFunction
	return {
		kind = "type_function",
		body = body,
		parameters = parameters,
	}
end

local function create_type_instantiation(
	type_function: TyId<TypeFunction>,
	arguments: { Ty },
	body: Ty
): TypeInstantiation
	return {
		kind = "type_instantiation",
		body = body,
		arguments = arguments,
		type_function = type_function,
	}
end

--stylua: ignore
export type Ty = types.Ty
export type TyId<T = Ty> = types.TyId<T>
export type TyKind = types.TyKind

local RECURSIVE_TYS: { [TyKind]: boolean } = {
	map = true,
	array = true,
	struct = true,
	type_instantiation = true,
	discriminated_union = true,
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
	nnil = create_nil,

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
	union = create_union,
	discriminated_union = create_discriminated_union,
	unknown = create_unknown,

	blocked = create_blocked,
	generic = create_generic,
	reference = create_reference,
	type_function = create_type_function,
	type_instantiation = create_type_instantiation,

	field = create_field,
	variant = create_variant,

	is_possibly_recursive = is_possibly_recursive,

	format = format,
})
