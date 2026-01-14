local assert_panic = require("@util/assert_panic")
local ast = require("@ast")
local lookup = require("@hir/lookup")
local panic = require("@util/panic")
local report = require("@hir/report")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>
type TyKind = ty.TyKind

type Hir = types.Hir
type Node = ast.Node
type Hash = any

type Context = {
	read hir: Hir,
	read encountered: { [Ty]: true? },
}

local explore: (ctx: Context, tty: Ty) -> ()

local function inner_ty(hir: Hir, tty: Ty): Ty
	local result = tty
	while true do
		if result.kind == "reference" then
			result = lookup.ty_from_id(hir, result.to)
			continue
		elseif result.kind == "type_instantiation" then
			result = result.body
			continue
		end

		break
	end

	return result
end

local function is_optional_union(hir: Hir, tty: Ty): boolean
	tty = inner_ty(hir, tty)

	if tty.kind ~= "union" then
		return false
	end

	for _, component in tty.components do
		if component.kind == "nil" then
			return true
		end
	end

	return false
end

local function hash_ty(hir: Hir, tty: Ty): Hash
	tty = inner_ty(hir, tty)

	if tty.kind == "map" then
		return "table"
	elseif tty.kind == "array" then
		return "table"
	elseif tty.kind == "struct" then
		return "table"
	-- TODO: Move inner ifs into the outer if once typechecking bug is fixed
	elseif tty.kind == "instance" then
		if tty.class then
			return `Instance({tty.class.value})`
		end
	elseif tty.kind == "roblox_enum" and tty.type then
		return `Enum.{tty.type.value}`
	elseif tty.kind == "discriminated_union" then
		local variant_keys = table.create(#tty.variants) :: { string }
		for index, variant in tty.variants do
			local key = variant.key
			local stringified: string
			if key.kind == "string_literal" then
				stringified = `"{key.value}"`
			else
				stringified = tostring(key.value)
			end

			variant_keys[index] = stringified
		end

		return `{tty.tag} ({table.concat(variant_keys)})`
	elseif tty.kind == "string_literal" then
		return `"{tty.value}"`
	elseif tty.kind == "number_literal" then
		return tty.value
	elseif tty.kind == "boolean_literal" then
		return tty.value
	elseif tty.kind == "reference" then
		panic("tried to hash reference")
	elseif tty.kind == "type_instantiation" then
		panic("tried to hash type instantiation")
	end

	return tty.kind
end

local function assert_ty_kind(tty: Ty, kind: TyKind)
	local real_kind = tty.kind
	if real_kind ~= kind then
		local node = assert_panic(tty.node, "Expected Ty to have an AST node")
		report.expect(node, kind, real_kind)
	end
end

local function assert_ty_kind_one_of(tty: Ty, kinds: { TyKind })
	local real_kind = tty.kind
	if table.find(kinds, real_kind) == nil then
		local node = assert_panic(tty.node, "Expected Ty to have an AST node")
		report.expect_one_of(node, kinds :: { string }, real_kind)
	end
end

local function assert_axis_ty(tty: Ty)
	assert_ty_kind_one_of(tty, { "numeral", "number_literal" })

	if tty.kind ~= "numeral" then
		return
	end

	local size = tonumber(tty.size) :: number
	local format = tty.format

	if (format == "f" and size > 32) or (format ~= "f" and size > 24) then
		local node = assert_panic(tty.node, "Expected Ty to have an AST node")
		report.cannot_represent_vector_axis(node)
	end
end

local function check_map(ctx: Context, map: ty.Map)
	local hir = ctx.hir

	local indexer = map.index
	if is_optional_union(hir, map.index) then
		local node = assert_panic(indexer.node, "Expected map indexer Ty to have an AST node")
		report.optional_indexer(node)
	end

	local value = map.value
	if is_optional_union(hir, map.value) then
		local node = assert_panic(value.node, "Expected map value Ty to have an AST node")
		report.optional_value(node)
	end

	explore(ctx, indexer)
	explore(ctx, value)
end

local function check_union(ctx: Context, union: ty.Union)
	local encountered_hashes: { [Hash]: Ty? } = {}
	for index, component in union.components do
		local hash = hash_ty(ctx.hir, component)
		local previous = encountered_hashes[hash]
		if previous then
			local union_node = assert_panic(union.node, "Expected union to have an AST node")
			local previous_node = assert_panic(previous.node, "Expected previous component to have an AST node")
			local duplicate_node = assert_panic(component.node, "Expected duplicate component to have an AST node")
			report.duplicate_union_type(union_node, duplicate_node, previous_node)
		end

		encountered_hashes[hash] = component
		explore(ctx, component)
	end
end

function explore(ctx: Context, tty: Ty)
	local encountered = ctx.encountered
	if encountered[tty] then
		return
	end

	encountered[tty] = true

	if tty.kind == "map" then
		check_map(ctx, tty)
	elseif tty.kind == "array" then
		explore(ctx, tty.of)
	elseif tty.kind == "struct" then
		for index, field in tty.fields do
			explore(ctx, field.value)
		end
	elseif tty.kind == "union" then
		check_union(ctx, tty)
	elseif tty.kind == "discriminated_union" then
		for index, variant in tty.variants do
			explore(ctx, variant.key)
			explore(ctx, variant.value)
		end
	elseif tty.kind == "type_instantiation" then
		explore(ctx, tty.body)
	elseif tty.kind == "vector" then
		for _, axis in { tty.x, tty.y, tty.z } do
			if axis == nil then
				break
			end

			assert_axis_ty(axis)
		end
	elseif tty.kind == "cframe" then
		if tty.position then
			assert_ty_kind(tty.position, "numeral")
			assert_axis_ty(tty.position)
		end

		if tty.rotation then
			assert_ty_kind(tty.rotation, "numeral")
		end
	elseif tty.kind == "instance" and tty.class then
		assert_ty_kind(tty.class, "string_literal")
	elseif tty.kind == "roblox_enum" and tty.type then
		assert_ty_kind(tty.type, "string_literal")
	end
end

local function type_check(hir: Hir)
	local tys = hir.tys
	for ty_id, tty in tys do
		local context: Context = {
			hir = hir,
			node = lookup.node_from_id(hir, ty_id :: ast.NodeId),
			encountered = {},
		}

		explore(context, tty)
	end
end

return table.freeze({
	type_check = type_check,
})
