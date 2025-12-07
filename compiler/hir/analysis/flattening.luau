local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type TyId<T = Ty> = ty.TyId<T>

type Hir = types.Hir
type Context = {
	read hir: Hir,
	read encountered: { [Ty]: true? },
}

local function ty_ptr_eq(a: Ty, b: Ty): boolean
	return (a :: any == b :: any)
end

local function transform(ctx: Context, tty: Ty): Ty
	local encountered = ctx.encountered
	if encountered[tty] then
		return tty
	end

	encountered[tty] = true

	if tty.kind == "map" then
		local index = transform(ctx, tty.index) :: any
		local value = transform(ctx, tty.value) :: any
		if index ~= tty.index or value ~= tty.value then
			return ty.map(index, value, tty.size)
		end
	elseif tty.kind == "array" then
		local of = transform(ctx, tty.of) :: any
		if tty.of ~= of then
			return ty.array(of :: Ty)
		end
	elseif tty.kind == "struct" then
		local fields = table.clone(tty.fields)
		local invalidated = false
		for index, field in fields do
			local value = transform(ctx, field.value) :: any
			if value ~= field.value then
				invalidated = true
				fields[index] = ty.field(field.name, value :: Ty)
			end
		end

		if invalidated then
			return ty.struct(fields)
		end
	elseif tty.kind == "union" then
		local new_components = table.create(#tty.components) :: typeof(tty.components)
		local invalidated = false

		local queue = { tty.components } :: { { Ty } }
		local nil_inserted = false
		while true do
			--TODO: Remove cast once table.remove decides to work
			local components = table.remove(queue) :: { Ty }?
			if components == nil then
				break
			end

			for _, component in components do
				if component.kind == "union" then
					table.insert(queue, component.components)
					continue
				end

				local transformed = transform(ctx, component)
				if not ty_ptr_eq(transformed, component) then
					invalidated = true
				end

				if transformed.kind == "nil" then
					if nil_inserted then
						invalidated = true
						continue
					end

					nil_inserted = true
				end

				table.insert(new_components, transformed)
			end
		end

		if invalidated then
			return ty.union(new_components)
		end
	elseif tty.kind == "discriminated_union" then
		local variants = table.clone(tty.variants)
		local invalidated = false
		for index, variant in variants do
			local key = transform(ctx, variant.key) :: any
			local value = transform(ctx, variant.value) :: any
			if key ~= variant.key or variant.value ~= value then
				invalidated = true
				variants[index] = ty.variant(key, value)
			end
		end

		if invalidated then
			return ty.discriminated_union(tty.tag, variants)
		end
	elseif tty.kind == "type_instantiation" then
		local body = transform(ctx, tty.body) :: any
		if tty.body ~= body then
			return ty.type_instantiation(tty.type_function, tty.arguments, body :: Ty)
		end
	elseif tty.kind == "reference" and tty.arguments then
		local arguments = table.clone(tty.arguments)
		local invalidated = false

		for index, argument in arguments do
			local new_argument = transform(ctx, argument) :: any
			if argument ~= new_argument then
				invalidated = true
				arguments[index] = new_argument
			end
		end

		if invalidated then
			return ty.reference(tty.to, arguments)
		end
	end

	return tty
end

local function flatten(hir: Hir)
	local tys = hir.tys
	for ty_id, tty in tys do
		local ctx: Context = {
			hir = hir,
			encountered = {},
		}

		tys[ty_id] = transform(ctx, tty)
	end
end

return table.freeze({
	flatten = flatten,
})
