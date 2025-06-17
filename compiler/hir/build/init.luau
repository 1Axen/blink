--!strict
--!native
--!optimize 2

local id = require("@compiler/id")
local types = require("@config/compilation")

local ast = require("@ast/types")
local hir = require("@hir/types")
local ty = require("@ty/types")

local bounds = require("@config/bounds")
local primitives = require("@config/primitives")

local panic = require("@util/panic")
local range = require("@util/range")
local symbols = require("@util/symbols")

local attributes = require("@self/attributes")
local report = require("@hir/report")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")

type Ty = ty.Ty
type Decl = hir.Decl
type Node = ast.Node

type Hir = hir.Hir
type Ast = ast.Ast

type TyId<T = Ty> = ty.TyId<T>
type DeclId<T = Decl> = hir.DeclId<T>
type NodeId<T = Node> = ast.NodeId<T>
type ScopeId = hir.ScopeId

type TyKind = ty.TyKind

type Range = range.Range
type Symbols = ast.Symbols

type Generics = {
	args: { TyId<ty.Generic> },
	values: { [string]: TyId<ty.Generic> },
}

type Context = {
	read hir: Hir,
	read file_id: number,

	scope: ScopeId,
	symbols: Symbols,
	generics: Generics?,
}

local block: (ctx: Context, node: ast.Block) -> ()
local statement: (ctx: Context, stat: ast.Statement) -> DeclId?
local expression: (ctx: Context, expr: ast.Expression, node_id: NodeId?, generics: Generics?) -> TyId<any>

local function path_to_segments(path: ast.Path): { string }
	local segments: { string } = {}
	for _, segment in path.segments do
		table.insert(segments, segment.value)
	end

	return segments
end

local function path_to_string(path: ast.Path): string
	return table.concat(path_to_segments(path), ".")
end

local function decl_from_id_optional(ctx: Context, decl_id: DeclId): Decl?
	return ctx.hir.decls[decl_id]
end

local function store_node(ctx: Context, node: Node): NodeId
	ctx.hir.nodes[node.id] = node
	return node.id
end

--- Creates an inner scope and returns the `scope_id` of the previous scope
local function inner_scope(ctx: Context, scope_id: ScopeId, scope_name: string): ScopeId
	local hir = ctx.hir
	local prev = ctx.scope
	local name = hir.scopes[prev]
	if name ~= nil then
		scope_name = `{name}_{scope_name}`
	end

	ctx.scope = scope_id
	hir.scopes[scope_id] = scope_name

	return prev
end

local function assert_identifier_one_of(ctx: Context, ident: ast.Identifier, valid: { string }): ast.Identifier
	local value = ident.value
	if table.find(valid, value) == nil then
		--TODO: Remove cast when Luau solver bug is fixed
		return report.expect_one_of(ident :: any, valid, value)
	end

	return ident
end

--- Converts an ast `Range` node to a `Range` class
--- Range is validated to be within the `bounds` passed
local function range_node_to_range_class(node: ast.Range, bounds: Range): Range
	local max_node = node.max
	local min_node = node.min

	local max = max_node and max_node.value or bounds.max
	local min = min_node and min_node.value or bounds.min

	if max > bounds.max or min < bounds.min then
		return report.unrepresentable_range(node, bounds)
	end

	return range.create(min, max)
end

--> Luau Primitives

local function ty_string_literal(ctx: Context, expr: ast.ExprString): ty.StringLiteral
	return ty.string_literal(expr.value)
end

local function ty_number_literal(ctx: Context, expr: ast.ExprNumber): ty.NumberLiteral
	return ty.number_literal(expr.value)
end

local function ty_boolean_literal(ctx: Context, expr: ast.ExprBoolean): ty.BooleanLiteral
	return ty.boolean_literal(expr.value)
end

local function ty_numeral(ctx: Context, identifier: string, expr_range: ast.Range?): ty.Numeral
	local numeral: primitives.Primitive = (primitives :: any)[identifier]

	local size: ty.NumSize = string.sub(identifier, 2, 3) :: ty.NumSize
	local format: ty.NumFormat = string.sub(identifier, 1, 1) :: ty.NumFormat
	local range: Range?

	if expr_range then
		range = range_node_to_range_class(expr_range, numeral.range or primitives.f64.range)
	end

	return ty.numeral(size, format, range)
end

local function ty_string(ctx: Context, expr_range: ast.Range?): ty.String
	local bounds = primitives.string.range
	local length = if expr_range then range_node_to_range_class(expr_range, bounds) else nil
	return ty.string(length)
end

local function ty_buffer(ctx: Context, expr_range: ast.Range?): ty.Buffer
	local bounds = primitives.buffer.range
	local length = if expr_range then range_node_to_range_class(expr_range, bounds) else nil
	return ty.buffer(length)
end

local function ty_vector(ctx: Context, expr: ast.ExprReference): ty.Vector
	local expr_range = expr.range
	local expr_generics = expr.generics

	local magnitude: Range?
	if expr_range then
		magnitude = range_node_to_range_class(expr_range, primitives.vector.range)
	end

	local axes: { ty.Axis } = {}
	if expr_generics then
		local values = expr_generics.values
		if #values > 3 then
			return report.extra_generics(expr_generics, 3)
		end

		for index, value in values do
			axes[index] = expression(ctx, value) :: ty.Axis
		end
	end

	return ty.vector(axes, magnitude)
end

local function ty_boolean(ctx: Context): ty.Boolean
	return ty.boolean()
end

local function ty_unknown(ctx: Context): ty.Unknown
	return ty.unknown()
end

--> ROBLOX Primitives

local function ty_roblox_enum(ctx: Context, expr_generics: ast.GenericsArgs?): ty.Enum
	local enum_type: TyId<ty.StringLiteral>?
	if expr_generics then
		local values = expr_generics.values
		if #values > 1 then
			return report.extra_generics(expr_generics, 1)
		end

		local generic = values[1]
		enum_type = expression(ctx, generic) :: TyId<ty.StringLiteral>
	end

	return ty.roblox_enum(enum_type)
end

local function ty_color3(ctx: Context): ty.Color3
	return ty.color3()
end

local function ty_cframe(ctx: Context, expr_generics: ast.GenericsArgs?): ty.CFrame
	local generics: { TyId<ty.Numeral> } = {}
	if expr_generics then
		local values = expr_generics.values
		if #values > 2 then
			return report.extra_generics(expr_generics, 2)
		end

		for index, value in values do
			local ty_id = expression(ctx, value) :: TyId<ty.Numeral>
			generics[index] = ty_id
		end
	end

	return ty.cframe(generics[1], generics[2])
end

local function ty_date_time(ctx: Context): ty.DateTime
	return ty.date_time()
end

local function ty_date_time_millis(ctx: Context): ty.DateTimeMillis
	return ty.date_time_millis()
end

local function ty_brick_color(ctx: Context): ty.BrickColor
	return ty.brick_color()
end

local function ty_instance(ctx: Context, expr_generics: ast.GenericsArgs?): ty.Instance
	local class: TyId<ty.StringLiteral>?
	if expr_generics then
		local values = expr_generics.values
		if #values > 1 then
			return report.extra_generics(expr_generics, 1)
		end

		class = expression(ctx, values[1]) :: TyId<ty.StringLiteral>
	end

	return ty.instance(class)
end

--- Returns a `ty` from a `reference` **to a primitive (u8, string, buffer, etc.)**
local function ty_from_reference(ctx: Context, expr: ast.ExprReference, path: string): Ty
	if
		path == "u8"
		or path == "u16"
		or path == "u24"
		or path == "u32"
		or path == "u48"
		or path == "i8"
		or path == "i16"
		or path == "i24"
		or path == "i32"
		or path == "i48"
		or path == "f16"
		or path == "f32"
		or path == "f64"
	then
		return ty_numeral(ctx, path, expr.range)
	elseif path == "string" then
		return ty_string(ctx, expr.range)
	elseif path == "buffer" then
		return ty_buffer(ctx, expr.range)
	elseif path == "vector" then
		return ty_vector(ctx, expr)
	elseif path == "boolean" then
		return ty_boolean(ctx)
	elseif path == "unknown" then
		return ty_unknown(ctx)
	elseif path == "Enum" then
		return ty_roblox_enum(ctx, expr.generics)
	elseif path == "CFrame" then
		return ty_cframe(ctx, expr.generics)
	elseif path == "Instance" then
		return ty_instance(ctx, expr.generics)
	elseif path == "Color3" then
		return ty_color3(ctx)
	elseif path == "DateTime" then
		return ty_date_time(ctx)
	elseif path == "BrickColor" then
		return ty_brick_color(ctx)
	elseif path == "DateTimeMillis" then
		return ty_date_time_millis(ctx)
	end

	return panic(`Unhandled primitive "{path}"`)
end

local function ty_set(ctx: Context, expr: ast.ExprSet): ty.Set
	local items: { ty.StringLiteral } = {}
	for _, value in expr.values do
		table.insert(items, ty_string_literal(ctx, (value :: any) :: ast.ExprString))
	end

	return ty.set(items)
end

local function ty_map(ctx: Context, expr: ast.ExprMap): ty.Map
	local index = expression(ctx, expr.index)
	local value = expression(ctx, expr.value)

	local range: Range
	if expr.range then
		range = range_node_to_range_class(expr.range, bounds.map)
	end

	return ty.map(index, value, range)
end

local function ty_unit_enum(ctx: Context, expr: ast.ExprEnum): ty.UnitEnum
	local variants: { string } = {}
	for _, variant in expr.variants do
		table.insert(variants, variant.value)
	end

	return ty.unit_enum(variants)
end

local function ty_array(ctx: Context, expr: ast.ExprArray): ty.Array
	local of = expression(ctx, expr.value)
	local size: Range?
	if expr.range then
		size = range_node_to_range_class(expr.range, bounds.array)
	end

	return ty.array(of, size)
end

local function ty_field(ctx: Context, expr: ast.ExprField): ty.Field
	local name = expr.name.value
	local value = expression(ctx, expr.value)
	return ty.field(name, value)
end

local function ty_struct(ctx: Context, expr: ast.ExprStruct): ty.Struct
	local fields: { ty.Field } = {}
	for index, field in expr.fields do
		fields[index] = ty_field(ctx, field)
	end

	return ty.struct(fields)
end

local function ty_intersection(ctx: Context, expr: ast.ExprUnion): ty.Intersection
	local left = expression(ctx, expr.left) :: TyId<ty.IntersectionSide>
	local right = expression(ctx, expr.right) :: TyId<ty.IntersectionSide>
	return ty.intersection(left, right)
end

local function ty_optional(ctx: Context, expr: ast.ExprOptional): ty.Optional
	local of = expression(ctx, expr.value)
	return ty.optional(of)
end

local function ty_tagged_enum(ctx: Context, expr: ast.ExprTaggedEnum): ty.TaggedEnum
	local tag = expr.tag.value
	local variants: { ty.Variant } = {}
	for index, node in expr.variants do
		local key = expression(ctx, node.key) :: TyId<ty.Literal>
		local value = ty_struct(ctx, node.value)
		local variant = ty.variant(key, value)

		-- add tag field to variant struct
		local struct = variant.value
		table.insert(struct.fields, 1, ty.field(tag, key :: TyId))

		variants[index] = variant
	end

	return ty.tagged_enum(tag, variants)
end

--- Returns the `ty_id` of the `ty` referenced
local function ty_id_from_reference(ctx: Context, expr: ast.ExprReference, expr_ty_id: TyId): TyId<Ty>
	--[[
        Phases:
        1 - Check if the reference is a generic parameter, return the generic parameter if it is, otherwise Continue
        2 - Check whether the reference exists, continue if it does, otherwise report an unknown reference
        3 - If any generics were passed alongside the reference convert them into an array of corresponding ty's

        4 - Check whether the reference exiusts, return a placeholder to it if it doesn't, otherwise continue
        5 - If any generics were passed then check whether the referenced ty accepts generics, if it does then continue to 5.1, else report extra generics
        5.1 - Validate whether the exact amount of generics were passed, report too few or too many if not, else create a new ty (generic type) and return it
        6 - Return the referenced ty
    --]]

	-- Phase 1:
	if ctx.generics then
		local path_string = path_to_string(expr.path)
		local generic = ctx.generics.values[path_string] :: TyId
		if generic then
			-- The type is the generic
			local node_id = id.ty_id.to_node_id(expr_ty_id)
			local expr_node = hir.node_from_id(ctx.hir, node_id)
			if expr_node.kind == "type" then
				local generic_ty = hir.ty_from_id(ctx.hir, generic) :: ty.Generic
				local new_ty: ty.GenericType = ty.generic_type(generic_ty, { generic })
				ctx.hir.tys[expr_ty_id] = new_ty
				return expr_ty_id
			end

			return generic
		end
	end

	-- Phase 2:
	local path_segments = path_to_segments(expr.path)
	local decl_node = symbols.search(ctx.symbols, path_segments)
	if decl_node == nil or decl_node.kind ~= "type" then
		return report.unknown_reference(expr)
	end

	local decl_node_id = decl_node.id
	local decl_id = id.node_id.to_decl_id(decl_node_id)
	local decl = decl_from_id_optional(ctx, decl_id) :: hir.Type?

	-- Phase 3:
	local generics: { TyId<Ty> } = {}
	local expr_generics = expr.generics
	if expr_generics then
		for index, value in expr_generics.values do
			generics[index] = expression(ctx, value)
		end
	end

	-- Phase 4:
	if decl == nil then
		local placeholder = ty.placeholder(path_segments, generics)
		ctx.hir.tys[expr_ty_id] = placeholder
		return expr_ty_id
	end

	-- Phase 5:
	local decl_generics = decl.generics
	if decl_generics then
		-- Phase 5.1:
		local n_decl_generics = #decl_generics
		if expr_generics == nil then
			return report.few_none_generics(expr.path, n_decl_generics)
		end

		local n_expr_generics = #expr_generics.values
		if n_expr_generics > n_decl_generics then
			return report.extra_generics(expr_generics, n_decl_generics)
		elseif n_expr_generics < n_decl_generics then
			return report.few_generics(expr_generics, n_decl_generics)
		end

		local decl_ty = hir.ty_from_id(ctx.hir, decl.ty) :: ty.GenericType
		local new_ty: ty.GenericType = ty.generic_type(decl_ty.def, generics)
		ctx.hir.tys[expr_ty_id] = new_ty

		return expr_ty_id
	elseif expr_generics then
		return report.extra_generics(expr_generics, 0)
	end

	-- Phase 6:
	return decl.ty
end

function expression(
	ctx: Context,
	expr: ast.Expression | ast.Identifier,
	node_id: NodeId?,
	generics: Generics?
): TyId<Ty>
	node_id = node_id or store_node(ctx, expr)
	local ty_id = id.node_id.to_ty_id(node_id)

	if generics ~= nil then
		ctx.generics = generics
	end

	--> process node
	local new_ty: Ty
	if expr.kind == "set" then
		new_ty = ty_set(ctx, expr)
	elseif expr.kind == "map" then
		new_ty = ty_map(ctx, expr)
	elseif expr.kind == "enum" then
		new_ty = ty_unit_enum(ctx, expr)
	elseif expr.kind == "array" then
		new_ty = ty_array(ctx, expr)
	elseif expr.kind == "union" then
		--TODO: Remove cast when Luau bug is fixed
		new_ty = ty_intersection(ctx, expr) :: Ty
	elseif expr.kind == "string" then
		new_ty = ty_string_literal(ctx, expr)
	elseif expr.kind == "struct" then
		new_ty = ty_struct(ctx, expr)
	elseif expr.kind == "number" then
		new_ty = ty_number_literal(ctx, expr)
	elseif expr.kind == "boolean" then
		--TODO: Remove cast when Luau bug is fixed
		new_ty = ty_boolean_literal(ctx, expr :: any)
	elseif expr.kind == "tagged_enum" then
		--TODO: Remove cast when Luau bug is fixed
		new_ty = ty_tagged_enum(ctx, expr :: any)
	elseif expr.kind == "optional" then
		--TODO: Remove cast when Luau bug is fixed
		new_ty = ty_optional(ctx, expr :: any)
	elseif expr.kind == "reference" then
		--TODO: Remove when Luau bug is fixed
		expr = expr :: ast.ExprReference

		local path = path_to_string(expr.path)
		local primitive = (primitives :: any)[path]
		if primitive == nil then
			return ty_id_from_reference(ctx, expr, ty_id)
		end

		new_ty = ty_from_reference(ctx, expr, path)
	elseif expr.kind == "identifier" then
		new_ty = ty_string_literal(ctx, expr :: any)
	else
		return strong_exhaustive_match(expr.kind)
	end

	if generics then
		new_ty = ty.generic_type(new_ty, generics.args :: { TyId })
		ctx.generics = nil
	end

	--> store ty
	ctx.hir.tys[ty_id] = new_ty

	return ty_id
end

local function expr_pack(ctx: Context, expr: ast.ExprPack): { hir.Parameter }
	local parameters: { hir.Parameter } = {}
	for index, expr in expr.values do
		local name = if expr.name then expr.name.value else nil
		local value = expression(ctx, expr.value)
		local parameter: hir.Parameter = {
			name = name,
			value = value,
		}

		table.insert(parameters, parameter)
	end

	return parameters
end

local function stat_type(ctx: Context, stat: ast.StatType): hir.Type
	local scope = ctx.scope

	--> set generics
	local args: { TyId<ty.Generic> }?
	local generics: Generics?
	local generics_def = stat.generics

	if generics_def then
		local values: { [string]: TyId<ty.Generic> } = {}
		args = {}

		for index, value in generics_def.values do
			local name = value.name
			local node_id = store_node(ctx, value)
			local ty_id = id.node_id.to_ty_id(node_id)
			local generic = ty.generic(name.value, index)

			ctx.hir.tys[ty_id] = generic
			args[index] = ty_id :: TyId<ty.Generic>
			values[name.value] = ty_id :: TyId<ty.Generic>
		end

		generics = {
			args = args,
			values = values,
		}
	end

	--> lower expression
	local node_id = store_node(ctx, stat)
	local ty_id = expression(ctx, stat.value, node_id, generics)

	return {
		kind = "type",
		name = stat.name.value,
		scope = scope,
		attributes = attributes.type(stat.attributes),

		ty = ty_id,
		generics = args,
	}
end

local function stat_scope(ctx: Context, stat: ast.StatScope)
	local name = stat.name.value
	local scope_id = id.node_id.to_scope_id(stat.id)

	--> set inner scope
	local parent = ctx.symbols
	local previous = inner_scope(ctx, scope_id, name)

	local scope_symbols = symbols.child(parent, name)
	if scope_symbols == nil then
		panic(`Scope "{name}" doesn't have symbols`)
		return
	end

	ctx.symbols = scope_symbols

	--> traverse scope stats
	block(ctx, stat.body)

	--> return previous scope
	ctx.scope = previous
	ctx.symbols = parent
end

local function stat_event(ctx: Context, stat: ast.StatEvent): hir.Event
	local name = stat.name.value
	local from = assert_identifier_one_of(ctx, stat.from, { "Client", "Server", "Both" }).value
	local call =
		assert_identifier_one_of(ctx, stat.call, { "ManySync", "SingleSync", "ManyAsync", "SingleAsync" }).value
	local poll = if stat.poll then stat.poll.value else false
	local data = if stat.data then expr_pack(ctx, stat.data) else nil
	local reliability = assert_identifier_one_of(ctx, stat.type, { "Reliable", "Unreliable" }).value

	return {
		kind = "event",
		scope = ctx.scope,
		attributes = attributes.shared(stat.attributes),

		name = name,
		from = from :: any,
		type = reliability :: any,
		call = call :: any,
		poll = poll,
		data = data,
	}
end

local function stat_function(ctx: Context, stat: ast.StatFunction): hir.Function
	local name = stat.name.value
	local yield = assert_identifier_one_of(ctx, stat.yield, { "Coroutine", "Promise", "Future" }).value
	local data = if stat.data then expr_pack(ctx, stat.data) else nil
	local ret = if stat.ret then expr_pack(ctx, stat.ret) else nil

	return {
		kind = "function",
		scope = ctx.scope,
		attributes = attributes.shared(stat.attributes),

		name = name,
		yield = yield :: any,
		data = data,
		ret = ret,
	}
end

function statement(ctx: Context, stat: ast.Statement): DeclId?
	--> assign node_id
	local node_id = store_node(ctx, stat)

	--> process node
	local decl: Decl?
	if stat.kind == "type" then
		decl = stat_type(ctx, stat)
	elseif stat.kind == "scope" then
		stat_scope(ctx, stat)
	elseif stat.kind == "event" then
		decl = stat_event(ctx, stat)
	elseif stat.kind == "function" then
		decl = stat_function(ctx, stat)
	end

	if decl == nil then
		return nil
	end

	local decl_id = id.node_id.to_decl_id(node_id)
	ctx.hir.decls[decl_id] = decl

	return decl_id
end

function block(ctx: Context, block: ast.Block)
	for _, stat in block.statements do
		statement(ctx, stat)
	end
end

local function substitute_placeholders(ctx: Context): never?
	--[[
        Phases:
        1: Get the AST node of the placeholder ty
        2: Get the declaration which the placeholder is of
        3: Get the ty and generics of the declaration
        4: Check whether the ty is self-recursive, report if it is, otherwise continue
        5: If the ty has generics, validate the amount of generics passed to it, report if they are too many/few, otherwise create a new `generic type` ty
        6: Replace the placeholder in the tys map with the declaration ty or created `generic type` ty
    --]]

	local tys = ctx.hir.tys
	for ty_id, placeholder in tys do
		local file_id = id.file(ty_id)
		if file_id ~= ctx.file_id then
			continue
		end

		if placeholder.kind ~= "placeholder" then
			continue
		end

		local path = placeholder.path
		local args = placeholder.args

		-- Phase 1:
		local node = hir.node_from_id(ctx.hir, id.ty_id.to_node_id(ty_id))
		local expr_node: ast.ExprReference

		if node.kind == "reference" then
			expr_node = node
		elseif node.kind == "type" then
			expr_node = node.value :: any
		end

		local expr_generics = expr_node.generics

		-- Phase 2:
		local decl_node: ast.StatType = symbols.search(ctx.symbols, path) :: any
		local decl_node_id = decl_node.id
		local decl_id = id.node_id.to_decl_id(decl_node_id)
		local decl: hir.Type = hir.decl_from_id(ctx.hir, decl_id) :: any

		-- Phase 3:
		local decl_ty = hir.ty_from_id(ctx.hir, decl.ty)
		local decl_generics = decl.generics

		-- Phase: 4
		if decl_ty == placeholder then
			return report.self_recursive_type(decl_node)
		elseif decl_ty.kind == "optional" and decl_ty.of == ty_id then
			return report.self_recursive_type(decl_node)
		end

		-- Phase: 5
		if decl_generics then
			local n_decl_generics = #decl_generics
			if args == nil then
				return report.few_none_generics(expr_node.path, n_decl_generics)
			end

			if expr_generics == nil then
				return panic("placeholder has args but origin node doesn't")
			end

			local n_args = #args
			if n_args < n_decl_generics then
				return report.few_generics(expr_generics, n_decl_generics)
			elseif n_args > n_decl_generics then
				return report.extra_generics(expr_generics, n_decl_generics)
			end

			decl_ty = hir.follow(ctx.hir, decl_ty)
			decl_ty = ty.generic_type(decl_ty, args)
		end

		-- Phase: 6
		tys[ty_id] = decl_ty
	end

	return nil
end

local function struct_ast(new_hir: Hir, file_id: number, ast: Ast)
	local ast_context: Context = {
		hir = new_hir,
		symbols = ast.symbols,
		file_id = file_id,

		scope = id.node_id.to_scope_id(ast.body.id),
		generics = nil :: any,
	}

	--> traverse the ast
	block(ast_context, ast.body)

	-- substitute placeholders with their final values
	substitute_placeholders(ast_context)
end

--[=[
    Constructs a HIR from the provided files map.
    @param `files` - A map of `file_id` to an `AST`. A `file_id` of **0** must always correspond to the **entry file**.
]=]
local function from_files(files: types.FilesMap): Hir
	local new_hir: Hir = {
		tys = {},
		decls = {},
		nodes = {},
		scopes = {},
		options = {},
	}

	-- traverse file asts
	for file_id, file_ast in files do
		struct_ast(new_hir, file_id, file_ast)
	end

	return new_hir
end

return table.freeze({
	from_files = from_files,
})
