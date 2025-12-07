local ast = require("@ast")
local lookup = require("@hir/lookup")
local report = require("@hir/report")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>
type TyKind = ty.TyKind

type Hir = types.Hir
type Context = {
	read hir: Hir,
	read node: ast.Node,
	read encountered: { [Ty]: true? },
}

local function assert_ty_kind(ctx: Context, ty: Ty, kind: TyKind)
	local real_kind = ty.kind
	if real_kind ~= kind then
		report.expect(ctx.node, kind, real_kind)
	end
end

local function assert_ty_kind_one_of(ctx: Context, ty: Ty, kinds: { TyKind })
	local real_kind = ty.kind
	if table.find(kinds, real_kind) == nil then
		report.expect_one_of(ctx.node, kinds :: { string }, real_kind)
	end
end

local function assert_axis_ty(ctx: Context, ty: Ty)
	assert_ty_kind_one_of(ctx, ty, { "numeral", "number_literal" })

	if ty.kind ~= "numeral" then
		return
	end

	local size = tonumber(ty.size) :: number
	local format = ty.format

	if (format == "f" and size > 32) or (format ~= "f" and size > 24) then
		report.cannot_represent_vector_axis(ctx.node)
	end
end

local function explore<T>(ctx: Context, tty: Ty)
	local encountered = ctx.encountered
	if encountered[tty] then
		return
	end

	encountered[tty] = true

	if tty.kind == "map" then
		explore(ctx, tty.index)
		explore(ctx, tty.value)
	elseif tty.kind == "array" then
		explore(ctx, tty.of)
	elseif tty.kind == "struct" then
		for index, field in tty.fields do
			explore(ctx, field.value)
		end
	elseif tty.kind == "union" then
		for index, component in tty.components do
			explore(ctx, component)
		end
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

			assert_axis_ty(ctx, axis)
		end
	elseif tty.kind == "cframe" then
		if tty.position then
			assert_ty_kind(ctx, tty.position, "numeral")
			assert_axis_ty(ctx, tty.position)
		end

		if tty.rotation then
			assert_ty_kind(ctx, tty.rotation, "numeral")
		end
	elseif tty.kind == "instance" and tty.class then
		assert_ty_kind(ctx, tty.class, "string_literal")
	elseif tty.kind == "roblox_enum" and tty.type then
		assert_ty_kind(ctx, tty.type, "string_literal")
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
