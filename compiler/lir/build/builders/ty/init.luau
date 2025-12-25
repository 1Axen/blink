local attributes = require("@config/attributes")
local binary = require("@builders/binary")
local builder_types = require("@self/builder_types")
local cast = require("@builders/cast")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local context = require("@lir/build/context")
local control = require("@builders/control")
local conversion = require("@util/conversion")
local fn = require("@builders/fn")
local globals = require("@builders/globals")
local hir = require("@hir")
local length = require("@builders/ty/luau/length")
local library = require("@builders/library")
local panic = require("@util/panic")
local prefixes = require("@config/prefixes")
local projection = require("@builders/projection")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local structure = require("@builders/structure")
local ty = require("@ty")
local ty_literal = require("@self/luau/literal")
local ty_numeral = require("@self/luau/numeral")
local types = require("@lir/types")
local unary = require("@builders/unary")

type Hir = hir.Hir

type Ty = ty.Ty
type TyId = ty.TyId<Ty>

type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps
type Props = builder_types.Props

local ALWAYS_TRUE = condition.equals(constant.truth, constant.truth)

local function ty_identity(tty: Ty): string
	return string.split(tostring(tty), ": ")[2]
end

--TODO: Make value optional when the solver is stable
local builders: { [ty.TyKind]: TyBuilder }
local function builder_from_ty(ty: Ty): TyBuilder
	local builder = builders[ty.kind]
	if builder == nil then
		return panic(`Unhandled ty kind: "{ty.kind}"`)
	end

	return builder
end

local function read_ty(props: ReadProps, block: Builder, ty: Ty, into: LValue<any>?): LValue<any>
	local builder = builder_from_ty(ty)
	return builder.read(props, block, ty, into)
end

local function write_ty(props: WriteProps, block: Builder, ty: Ty, value: RValue<any>)
	local builder = builder_from_ty(ty)
	builder.write(props, block, ty, value)
end

local function build_ty(ctx: Context, attributes: attributes.Attributes, tty: Ty, name: string?): types.FnSet
	local hhir = ctx.hir
	local key_ty = tty
	local inner_ty = tty

	if tty.kind == "reference" then
		inner_ty = hir.ty_from_id(hhir, tty.to)
		key_ty = inner_ty
	elseif tty.kind == "type_instantiation" then
		inner_ty = tty.body
	end

	local existing = ctx.ty_fn_set_map[key_ty]
	if existing then
		return existing
	end

	-- pre store the ids
	local read_fn_id = context.next_fn_id(ctx)
	local write_fn_id = context.next_fn_id(ctx)
	local fn_set: types.FnSet = {
		read = read_fn_id,
		write = write_fn_id,
	}

	ctx.ty_fn_set_map[key_ty] = fn_set

	-- build reader & writer
	name = name or ty_identity(tty)
	local read_name = projection.index(globals.types_map, constant.from_value(`{prefixes.ty}read_{name}`))
	local write_name = projection.index(globals.types_map, constant.from_value(`{prefixes.ty}write_{name}`))

	local read_fn = fn.create(read_name, {}, { fn.rreturn(tty) }, function(block)
		local props: ReadProps = {
			ctx = ctx,
			attributes = attributes,
		}

		local value_register = read_ty(props, block, inner_ty)
		block:rreturn({ value_register })
	end)

	local write_fn = fn.create(write_name, { fn.parameter(tty) }, {}, function(block)
		local props: WriteProps = {
			ctx = ctx,
			validate = true,
			attributes = attributes,
		}

		write_ty(props, block, inner_ty, block:parameter(1))
	end)

	context.store_fn(ctx, read_fn, read_fn_id)
	context.store_fn(ctx, write_fn, write_fn_id)

	return fn_set
end

builders = {
	["nil"] = require("@self/luau/null"),
	buffer = require("@self/luau/buffer"),
	string = require("@self/luau/string"),
	vector = require("@self/luau/vector"),
	numeral = ty_numeral,
	boolean = require("@self/luau/boolean"),

	string_literal = ty_literal,
	number_literal = ty_literal,
	boolean_literal = ty_literal,

	cframe = require("@self/roblox/cframe"),
	color3 = require("@self/roblox/color3"),
	unknown = require("@self/roblox/unknown"),
	instance = require("@self/roblox/instance"),
	date_time = require("@self/roblox/date_time"),
	brick_color = require("@self/roblox/brick_color"),
	roblox_enum = require("@self/roblox/enum"),
	date_time_millis = require("@self/roblox/date_time_millis"),
}

builders.reference = table.freeze({
	read = function(props: ReadProps, block: Builder, ref: ty.Reference, into: LValue<any>?): Register<any>
		local fn_set = build_ty(props.ctx, props.attributes, ref)
		local register = into or block:reserve()
		block:call_fn(fn_set.read, {}, { register })
		return register :: Register<any>
	end,
	write = function(props: WriteProps, block: Builder, ref: ty.Reference, at: RValue<any>): ()
		local fn_set = build_ty(props.ctx, props.attributes, ref)
		block:call_fn(fn_set.write, { at }, {})
	end,
})

builders.type_instantiation = table.freeze({
	read = function(
		props: ReadProps,
		block: Builder,
		instantiation: ty.TypeInstantiation,
		into: LValue<any>?
	): Register<any>
		local fn_set = build_ty(props.ctx, props.attributes, instantiation)
		local register = into or block:reserve()
		block:call_fn(fn_set.read, {}, { register })
		return register :: Register<any>
	end,
	write = function(props: WriteProps, block: Builder, instantiation: ty.TypeInstantiation, at: RValue<any>): ()
		local fn_set = build_ty(props.ctx, props.attributes, instantiation)
		block:call_fn(fn_set.write, { at }, {})
	end,
})

builders.map = table.freeze({
	read = function(props: ReadProps, block: Builder, map: ty.Map, into: LValue<any>?): Register<{ [any]: any }>
		local len = length.read(props, block, map)
		local register = block:store(structure.map({}))

		block:for_numeric(len, function(block)
			local key = read_ty(props, block, map.index)
			read_ty(props, block, map.value, projection.field(register, key))
		end)

		if into then
			return block:store(register, into)
		end

		return register
	end,
	write = function(props: WriteProps, block: Builder, map: ty.Map, at: RValue<{ [any]: any }>): ()
		local elements_register = block:store(constant.zero)
		local increase_elements = binary.add(elements_register, constant.one)
		block:for_generic(at, function(block)
			block:store(increase_elements, elements_register)
		end)

		length.write(props, block, map, elements_register)

		block:for_generic(at, function(block, key, value)
			write_ty(props, block, map.index, key)
			write_ty(props, block, map.value, value)
		end)
	end,
})

builders.array = table.freeze({
	read = function(props: ReadProps, block: Builder, array: ty.Array, into: LValue<any>?): Register<{ any }>
		local len = length.read(props, block, array)
		local register = block:store(library.table.create(len))

		block:for_numeric(len, function(block, index)
			local element = read_ty(props, block, array.of)
			local position = projection.field(register :: any, index)
			block:store(element, position)
		end)

		if into then
			return block:store(register, into)
		end

		return register
	end,
	write = function(props: WriteProps, block: Builder, array: ty.Array, value: RValue<{ any }>): ()
		length.write(props, block, array, unary.len(value :: any))
		block:for_generic(value :: any, function(block, _, value)
			write_ty(props, block, array.of, value)
		end)
	end,
})

builders.struct = table.freeze({
	read = function(props: ReadProps, block: Builder, struct: ty.Struct, into: LValue<any>?): Register<any>
		local identity = ty_identity(struct)
		local templates = props.ctx.templates
		if templates[identity] == nil then
			local template_fields = {}
			for _, field in struct.fields do
				template_fields[constant.from_value(field.name)] = cast.static(constant.null, "any") :: any
			end
			templates[identity] = structure.struct(template_fields)
		end

		local template = projection.field(globals.templates, constant.from_value(identity))
		local struct_register: Register<any> = block:store(library.table.clone(template))

		for _, field in struct.fields do
			local name = field.name
			local struct_index = projection.field(struct_register, constant.from_value(name))
			read_ty(props, block, field.value, struct_index)
		end

		if into then
			return block:store(struct_register, into)
		end

		return struct_register
	end,

	write = function(props: WriteProps, block: Builder, struct: ty.Struct, value: RValue<any>): ()
		for _, field in struct.fields do
			local name = field.name
			local struct_index = projection.field(value :: LValue<any>, constant.from_value(name))
			local field_register = block:store(struct_index)
			write_ty(props, block, field.value, field_register)
		end
	end,
})

builders.discriminated_union = table.freeze({
	read = function(props: ReadProps, block: Builder, enum: ty.DiscriminatedUnion, into: LValue<any>?)
		local variants = enum.variants
		local variants_count = #variants

		-- account for serdesing from 0
		local format = conversion.to_min_numeral(variants_count - 1)

		local value = into or block:reserve()
		local read_variant_index = ty_numeral.read(props, block, format)

		block:if_chain(variants_count + 1, function(index)
			if index > variants_count then
				return ALWAYS_TRUE,
					function(block: Builder)
						local message = library.string.format("Invalid enum variant %d", read_variant_index)
						block:call(library.error_rvalue(message))
					end
			end

			local variant_value = variants[index].value
			local variant_index = constant.from_value(index - 1)

			local is_variant = condition.equals(read_variant_index, variant_index)
			return is_variant,
				function(block: Builder)
					builders.struct.read(props, block, variant_value, value)
				end
		end)

		return value
	end,
	write = function(props: WriteProps, block: Builder, enum: ty.DiscriminatedUnion, value: RValue<any>): ()
		local variants = enum.variants
		local variants_count = #variants

		-- account for serdesing from 0
		local format = conversion.to_min_numeral(variants_count - 1)
		local tag_value = block:store(projection.field(value :: any, constant.from_value(enum.tag)))

		block:if_chain(variants_count + 1, function(index)
			if index > variants_count then
				return ALWAYS_TRUE,
					function(block: Builder)
						local message = library.string.format("Invalid enum variant %*", tag_value)
						block:call(library.error_rvalue(message))
					end
			end

			local variant = variants[index]
			local variant_value = variant.value
			local variant_index = constant.from_value(index - 1)

			local key = variant.key
			local is_variant = condition.equals(tag_value, constant.from_ty(key :: any))

			return is_variant,
				function(block: Builder)
					ty_numeral.write(props, block, format, variant_index)
					builders.struct.write(props, block, variant_value, value)
				end
		end)
	end,
})

do
	local KIND_PRIORITY: { [ty.TyKind]: number? } = {
		["nil"] = math.huge,
		["discriminated_union"] = 0,
		["map"] = -1,
		["array"] = -1,
		["struct"] = -1,
		["unknown"] = -math.huge,
	}

	local function ty_to_type(hhir: Hir, tty: Ty): string
		if tty.kind == "nil" then
			return "nil"
		elseif tty.kind == "map" then
			return "map"
		elseif tty.kind == "array" then
			return "table"
		elseif tty.kind == "struct" then
			return "table"
		elseif tty.kind == "union" then
			return panic("cannot get type of union")
		elseif tty.kind == "blocked" then
			return panic("cannot get type of blocked")
		elseif tty.kind == "generic" then
			return panic("cannot get type of generic")
		elseif tty.kind == "buffer" then
			return "buffer"
		elseif tty.kind == "vector" then
			return "Vector3"
		elseif tty.kind == "numeral" or tty.kind == "number_literal" then
			return "number"
		elseif tty.kind == "string" or tty.kind == "string_literal" then
			return "string"
		elseif tty.kind == "boolean" or tty.kind == "boolean_literal" then
			return "boolean"
		elseif tty.kind == "roblox_enum" then
			return "EnumItem"
		elseif tty.kind == "cframe" then
			return "CFrame"
		elseif tty.kind == "color3" then
			return "Color3"
		elseif tty.kind == "instance" then
			return "Instance"
		elseif tty.kind == "date_time" then
			return "DateTime"
		elseif tty.kind == "date_time_millis" then
			return "DateTimeMillis"
		elseif tty.kind == "brick_color" then
			return "BrickColor"
		elseif tty.kind == "unknown" then
			return "unknown"
		elseif tty.kind == "reference" then
			return ty_to_type(hhir, hir.ty_from_id(hhir, tty.to))
		elseif tty.kind == "type_instantiation" then
			return ty_to_type(hhir, tty.body)
		elseif tty.kind == "discriminated_union" then
			return "table"
		elseif tty.kind == "type_function" then
			return panic("cannot get type of type function")
		else
			return strong_exhaustive_match(tty.kind)
		end
	end

	local function ty_to_priority(tty: Ty): number
		local kind = tty.kind
		local priority = KIND_PRIORITY[kind] or #kind

		if (tty.kind == "instance" and tty.class) or (tty.kind == "roblox_enum" and tty.type) then
			priority += 1
		end

		return priority
	end

	local function sorted_components(hhir: Hir, union: ty.Union): { Ty }
		local components = table.clone(union.components)
		table.sort(components, function(a: Ty, b: Ty)
			return ty_to_priority(a) > ty_to_priority(b)
		end)
		return components
	end

	builders.union = table.freeze({
		read = function(props: ReadProps, block: Builder, union: ty.Union, into: LValue<any>?)
			local hhir = props.ctx.hir

			local components = sorted_components(hhir, union)
			local n_components = #components

			-- add extra else chain for invalid error if no unknown components
			local variants_index = 0
			local components_index = 0

			local value = into or block:reserve()
			local stored_index = block:store(library.buffer.u8.read(control.advance(constant.one)))

			block:if_chain(n_components + 1, function(index)
				if index > n_components then
					return ALWAYS_TRUE,
						function(block: Builder)
							local message = library.string.format("Invalid union type: %d", stored_index)
							block:call(library.error_rvalue(message))
						end
				end

				components_index += 1

				local component = components[components_index]
				local ty_to_read = component
				local component_index = constant.from_value(index - 1)

				if component.kind == "discriminated_union" then
					local variants = component.variants
					variants_index += 1

					local variant = variants[variants_index]
					if variants_index < #variants then
						components_index -= 1
					else
						variants_index = 0
					end

					ty_to_read = variant.value
				end

				return condition.equals(stored_index, component_index),
					function(block)
						read_ty(props, block, ty_to_read, value)
					end
			end)

			return value
		end,
		write = function(props: WriteProps, block: Builder, union: ty.Union, value: RValue<any>): ()
			local hhir = props.ctx.hir

			local components = sorted_components(hhir, union)
			local n_components = #components

			-- add extra else chain for invalid error if no unknown components
			local n_chains = n_components
			local is_optional = false
			local has_catch_case = false

			for _, component in components do
				if component.kind == "discriminated_union" then
					n_chains += #component.variants - 1
				end
			end

			do
				local first = components[1]
				local last = components[n_components]

				if first.kind == "nil" and n_components == 2 then
					is_optional = true
				elseif last.kind ~= "unknown" then
					n_chains += 1
					has_catch_case = true
				end
			end

			local variants_index = 0
			local components_index = 0

			local value_typeof = block:store(library.typeof(value))
			local write_offset = block:allocate(constant.one)

			block:if_chain(n_chains, function(index)
				if index == n_chains and has_catch_case then
					return ALWAYS_TRUE,
						function(block: Builder)
							local message = library.string.format("Invalid union type: %s", value_typeof)
							block:call(library.error_rvalue(message))
						end
				end

				components_index += 1

				local component = components[components_index]
				local ty_to_write = component

				local component_type = constant.from_value(ty_to_type(hhir, component))
				local component_condition = ALWAYS_TRUE

				if component.kind == "nil" then
					component_condition = condition.equals(value, constant.null)
				elseif component.kind == "instance" and component.class then
					local class = constant.from_value(component.class.value)
					local type_condition = condition.equals(value_typeof, component_type)
					local class_condition = condition.equals(library.Instance.is_a(value :: any, class), constant.truth)
					component_condition = condition.aand(type_condition, class_condition)
				elseif component.kind == "roblox_enum" and component.type then
					local enum_type =
						projection.index(constant.from_value("Enum"), constant.from_value(component.type.value))
					local real_enum_type = projection.index(value :: any, constant.from_value("EnumType"))

					local type_condition = condition.equals(value_typeof, component_type)
					local enum_type_condition = condition.equals(real_enum_type, enum_type)
					component_condition = condition.aand(type_condition, enum_type_condition)
				elseif component.kind == "discriminated_union" then
					local variants = component.variants
					variants_index += 1

					local variant = variants[variants_index]
					local tag_index = projection.field(value :: any, constant.from_value(component.tag))

					if variants_index < #variants then
						components_index -= 1
					else
						variants_index = 0
					end

					ty_to_write = variant.value

					local tag_condition = condition.equals(tag_index, constant.from_ty(variant.key :: any))
					local type_condition = condition.equals(value_typeof, constant.from_value("table"))
					component_condition = condition.aand(type_condition, tag_condition)
				elseif not is_optional and component.kind ~= "unknown" then
					component_condition = condition.equals(value_typeof, component_type)
				end

				return component_condition,
					function(block)
						block:call(library.buffer.u8.write(write_offset, constant.from_value(index - 1)))
						write_ty(props, block, ty_to_write, value)
					end
			end)
		end,
	})
end

return table.freeze({
	build = build_ty,
})
