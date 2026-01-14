--!strict

local ast = require("@ast")
local format = require("@self/format")
local panic = require("@util/panic")
local range = require("@util/range")
local types = require("@self/types")

type Range = range.Range
type Expression = ast.Expression

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
export type StreamedInstance = types.StreamedInstance
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

local function create_numeral(node: Expression?, size: NumSize, format: NumFormat, bounds: Range?): Numeral
	return {
		kind = "numeral",
		node = node,
		size = size,
		format = format,
	}
end

--- `axes` is an array of 0-3 TyIds (Numeral or NumberLiteral) corresponding to: x, y, z; in that order
local function create_vector(node: Expression?, axes: { Axis? }, magnitude: Range?): Vector
	return {
		kind = "vector",
		node = node,
		x = axes[1],
		y = axes[2],
		z = axes[3],
		magnitude = magnitude,
	}
end

local function create_buffer(node: Expression?, length: Range?): Buffer
	return {
		kind = "buffer",
		node = node,
		length = length,
	}
end

local function create_string(node: Expression?, length: Range?): String
	return {
		kind = "string",
		node = node,
		length = length,
	}
end

local function create_boolean(node: Expression?): Boolean
	return {
		kind = "boolean",
		node = node,
	}
end

local function create_nil(node: Expression?): Nil
	return {
		kind = "nil",
		node = node,
	}
end

local function create_string_literal(node: Expression?, value: string): StringLiteral
	return {
		kind = "string_literal",
		node = node,
		value = value,
	}
end

local function create_number_literal(node: Expression?, value: number): NumberLiteral
	return {
		kind = "number_literal",
		node = node,
		value = value,
	}
end

local function create_boolean_literal(node: Expression?, value: boolean): BooleanLiteral
	return {
		kind = "boolean_literal",
		node = node,
		value = value,
	}
end

local function create_literal(node: Expression?, value: index<Literal, "value">): Literal
	if type(value) == "string" then
		return create_string_literal(node, value)
	elseif type(value) == "number" then
		return create_number_literal(node, value)
	elseif type(value) == "boolean" then
		return create_boolean_literal(node, value)
	end

	return panic(`Unable to create literal from value of type "{type(value)}"`)
end

local function create_roblox_enum(node: Expression?, type: StringLiteral?): Enum
	return {
		kind = "roblox_enum",
		node = node,
		type = type,
	}
end

local function create_color3(node: Expression?): Color3
	return {
		kind = "color3",
		node = node,
	}
end

local function create_cframe(node: Expression?, position: Numeral?, rotation: Numeral?): CFrame
	return {
		kind = "cframe",
		node = node,
		position = position,
		rotation = rotation,
	}
end

local function create_date_time(node: Expression?): DateTime
	return {
		kind = "date_time",
		node = node,
	}
end

local function create_date_time_millis(node: Expression?): DateTimeMillis
	return {
		kind = "date_time_millis",
		node = node,
	}
end

local function create_brick_color(node: Expression?): BrickColor
	return {
		kind = "brick_color",
		node = node,
	}
end

local function create_instance(node: Expression?, class: StringLiteral?): Instance
	return {
		kind = "instance",
		node = node,
		class = class,
	}
end

local function create_streamed_instance(node: Expression?, class: StringLiteral?): StreamedInstance
	return {
		kind = "streamed_instance",
		node = node,
		class = class,
	}
end

local function create_map(node: Expression?, index: Ty, value: Ty, size: Range?): Map
	return {
		kind = "map",
		node = node,
		size = size,
		index = index,
		value = value,
	}
end

local function create_field(node: Expression?, name: string, value: Ty): Field
	return {
		kind = "field",
		node = node,
		name = name,
		value = value,
	}
end

local function create_struct(node: Expression?, fields: { Field }): Struct
	return {
		kind = "struct",
		node = node,
		fields = fields,
	}
end

local function create_array(node: Expression?, of: Ty, size: Range?): Array
	return {
		kind = "array",
		node = node,
		of = of,
		size = size,
	}
end

local function create_union(node: Expression?, components: { Ty }): Union
	return {
		kind = "union",
		node = node,
		components = components,
	}
end

local function create_variant(node: Expression?, key: Literal, value: Struct): Variant
	return {
		kind = "variant",
		node = node,
		key = key,
		value = value,
	}
end

local function create_discriminated_union(node: Expression?, tag: string, variants: { Variant }): DiscriminatedUnion
	return {
		kind = "discriminated_union",
		node = node,
		tag = tag,
		variants = variants,
	}
end

local function create_unknown(node: Expression?): Unknown
	return {
		kind = "unknown",
		node = node,
	}
end

local function create_blocked(node: Expression?): Blocked
	return {
		kind = "blocked",
		node = node,
	}
end

local function create_generic(node: Expression?, name: string, index: number): Generic
	return {
		kind = "generic",
		node = node,
		name = name,
		index = index,
	}
end

local function create_reference(node: Expression?, to: TyId, arguments: { Ty }?): Reference
	return {
		kind = "reference",
		node = node,
		to = to,
		arguments = arguments,
	}
end

local function create_type_function(node: Expression?, body: Ty, parameters: { Generic }): TypeFunction
	return {
		kind = "type_function",
		node = node,
		body = body,
		parameters = parameters,
	}
end

local function create_type_instantiation(
	node: Expression?,
	type_function: TyId<TypeFunction>,
	arguments: { Ty },
	body: Ty
): TypeInstantiation
	return {
		kind = "type_instantiation",
		node = node,
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
	streamed_instance = create_streamed_instance,
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
