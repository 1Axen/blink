local attributes = require("@config/attributes")
local binary = require("@builders/binary")
local builder_types = require("@self/builder_types")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local context = require("@lir/build/context")
local conversion = require("@util/conversion")
local fn = require("@builders/fn")
local globals = require("@builders/globals")
local hir = require("@hir")
local length = require("@builders/ty/luau/length")
local library = require("@builders/library")
local panic = require("@util/panic")
local prefixes = require("@config/prefixes")
local projection = require("@builders/projection")
local structure = require("@builders/structure")
local ty = require("@ty")
local ty_literal = require("@self/luau/literal")
local ty_numeral = require("@self/luau/numeral")
local types = require("@lir/types")
local unary = require("@builders/unary")

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

local function ty_to_str(tty: Ty): string
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
	name = name or ty_to_str(tty)
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
	["nil"] = require("@self/luau/nil"),
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

	reference = table.freeze({
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
	}),

	type_instantiation = table.freeze({
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
	}),

	map = table.freeze({
		read = function(props: ReadProps, block: Builder, map: ty.Map, into: LValue<any>?): Register<{ [any]: any }>
			local len = length.read(props, block, map)
			local register = block:store(structure.map({}))

			block:for_numeric(len, function(block)
				local key = read_ty(props, block, map.index)
				local value = read_ty(props, block, map.value)
				local map_index = projection.field(register, key)
				block:store(value, map_index)
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
	}),

	array = table.freeze({
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
	}),

	struct = table.freeze({
		read = function(props: ReadProps, block: Builder, struct: ty.Struct, into: LValue<any>?): Register<any>
			local register: Register<any> = block:store(structure.struct({}), into)
			for _, field in struct.fields do
				local name = field.name
				local struct_index = projection.field(register, constant.from_value(name))
				read_ty(props, block, field.value, struct_index)
			end

			return register
		end,

		write = function(props: WriteProps, block: Builder, struct: ty.Struct, value: RValue<any>): ()
			for _, field in struct.fields do
				local name = field.name
				local struct_index = projection.field(value :: LValue<any>, constant.from_value(name))
				local field_register = block:store(struct_index)
				write_ty(props, block, field.value, field_register)
			end
		end,
	}),

	discriminated_union = table.freeze({
		read = function(props: ReadProps, block: Builder, enum: ty.DiscriminatedUnion, into: LValue<any>?)
			local variants = enum.variants
			local variants_count = #variants

			-- account for serdesing from 0
			local format = conversion.to_min_numeral(variants_count - 1)

			local value = into or block:reserve()
			local stored_value = ty_numeral.read(props, block, format)

			block:if_chain(variants_count + 1, function(index)
				if index > variants_count then
					local fallback = condition.equals(constant.truth, constant.truth)
					return fallback,
						function(block: Builder)
							block:call(library.error("Invalid enum variant"))
						end
				end

				local variant_value = variants[index].value
				local variant_index = constant.from_value(index - 1)

				local is_variant = condition.equals(stored_value, variant_index)
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
					local fallback = condition.equals(constant.truth, constant.truth)
					return fallback,
						function(block: Builder)
							block:call(library.error("Invalid enum variant"))
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
	}),

	union = table.freeze({
		read = function(props: ReadProps, block: Builder, union: ty.Union, into: LValue<any>?): Register<any>
			local register: Register<any> = block:store(structure.struct({}))

			return register
		end,
		write = function(props: WriteProps, block: Builder, union: ty.Union, value: RValue<any>): () end,
	}),
}

return table.freeze({
	build = build_ty,
})
