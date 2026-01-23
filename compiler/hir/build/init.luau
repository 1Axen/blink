--!strict
--!native
--!optimize 2

local ast = require("@ast")
local bounds = require("@config/bounds")
local collect_decls = require("@self/collect_decls")
local compilation = require("@config/compilation")
local lookup = require("@hir/lookup")
local panic = require("@util/panic")
local range = require("@util/range")
local report = require("@compiler/report")
local store_node = require("@self/store_node")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local symbols = require("@compiler/symbols")
local ty = require("@ty")
local types = require("@hir/types")

type Ty = ty.Ty
type Decl = types.Decl
type Node = ast.Node
type Hir = types.Hir
type Ast = ast.Ast

type TyId<T = Ty> = ty.TyId<T>
type DeclId = types.DeclId
type NodeId = ast.NodeId
type ScopeId = types.ScopeId

type SealedRange = range.SealedRange

type Symbols = ast.Symbols
type Collection = collect_decls.Collection

type Generics = {
	by_name: { [string]: ty.Generic },
	parameters: { ty.Generic },
}

type Context = {
	read hir: Hir,

	symbols: Symbols,
	scope_id: ScopeId,
	generics: Generics?,
}

local expression: (ctx: Context, expr: ast.Expression, node_id: NodeId?, generics: Generics?) -> TyId<any>

local function path_node_to_segments(path: ast.Path): { string }
	local segments: { string } = {}
	for _, segment in path.segments do
		table.insert(segments, segment.value)
	end

	return segments
end

local function path_node_to_string(path: ast.Path): string
	return table.concat(path_node_to_segments(path), ".")
end

--- Converts an ast `Range` node to a `Range` object
--- Range is validated to be within the `bounds` passed
local function range_from_node(node: ast.Range, bounds: SealedRange): SealedRange
	local max_node = node.max
	local min_node = node.min

	local max = max_node and max_node.value or bounds.max
	local min = min_node and min_node.value or bounds.min

	if max > bounds.max or min < bounds.min then
		return report.unrepresentable_range(node, bounds)
	elseif min > max then
		return report.invalid_range(node)
	end

	return range.sealed(min, max)
end

--> Luau Primitives

local function ty_string_literal(ctx: Context, expr: ast.ExprString): ty.StringLiteral
	return ty.string_literal(expr, expr.value)
end

local function ty_number_literal(ctx: Context, expr: ast.ExprNumber): ty.NumberLiteral
	return ty.number_literal(expr, expr.value)
end

local function ty_boolean_literal(ctx: Context, expr: ast.ExprBoolean): ty.BooleanLiteral
	return ty.boolean_literal(expr, expr.value)
end

local function ty_numeral(ctx: Context, expr: ast.ExprReference, identifier: string): ty.Numeral
	local size: ty.NumSize = string.sub(identifier, 2, 3) :: ty.NumSize
	local format: ty.NumFormat = string.sub(identifier, 1, 1) :: ty.NumFormat

	local range: SealedRange?
	local bounds: SealedRange = (bounds :: any)[identifier]
	if expr.range then
		range = range_from_node(expr.range, bounds)
	end

	return ty.numeral(expr, size, format, range)
end

local function ty_string(ctx: Context, expr: ast.ExprReference): ty.String
	local bounds = bounds.string
	local length = if expr.range then range_from_node(expr.range, bounds) else nil
	return ty.string(expr, length)
end

local function ty_buffer(ctx: Context, expr: ast.ExprReference): ty.Buffer
	local bounds = bounds.buffer
	local length = if expr.range then range_from_node(expr.range, bounds) else nil
	return ty.buffer(expr, length)
end

local function ty_vector(ctx: Context, expr: ast.ExprReference): ty.Vector
	local expr_range = expr.range
	local expr_generics = expr.generics

	local magnitude: SealedRange?
	if expr_range then
		magnitude = range_from_node(expr_range, bounds.vector)
	end

	local axes: { ty.Axis? } = {}
	if expr_generics then
		local values = expr_generics.values
		if #values > 3 then
			return report.extra_generics(expr_generics, 3)
		end

		for index, value in values do
			axes[index] = expression(ctx, value) :: ty.Axis
		end
	end

	return ty.vector(expr, axes, magnitude)
end

local function ty_boolean(ctx: Context, expr: ast.ExprReference): ty.Boolean
	return ty.boolean(expr)
end

local function ty_unknown(ctx: Context, expr: ast.ExprReference): ty.Unknown
	return ty.unknown(expr)
end

--> ROBLOX Primitives

local function ty_roblox_enum(ctx: Context, expr: ast.ExprReference): ty.Enum
	local enum_type: ty.StringLiteral?
	local parameters = expr.generics
	if parameters then
		local values = parameters.values
		if #values > 1 then
			return report.extra_generics(parameters, 1)
		end

		local generic = values[1]
		enum_type = expression(ctx, generic) :: ty.StringLiteral
	end

	return ty.roblox_enum(expr, enum_type)
end

local function ty_color3(ctx: Context, expr: ast.ExprReference): ty.Color3
	return ty.color3(expr)
end

local function ty_cframe(ctx: Context, expr: ast.ExprReference): ty.CFrame
	local generics: { ty.Numeral } = {}
	local parameters = expr.generics
	if parameters then
		local values = parameters.values
		if #values > 2 then
			return report.extra_generics(parameters, 2)
		end

		for index, value in values do
			local ty_id = expression(ctx, value) :: ty.Numeral
			generics[index] = ty_id
		end
	end

	return ty.cframe(expr, generics[1], generics[2])
end

local function ty_date_time(ctx: Context, expr: ast.ExprReference): ty.DateTime
	return ty.date_time(expr)
end

local function ty_date_time_millis(ctx: Context, expr: ast.ExprReference): ty.DateTimeMillis
	return ty.date_time_millis(expr)
end

local function ty_brick_color(ctx: Context, expr: ast.ExprReference): ty.BrickColor
	return ty.brick_color(expr)
end

local function ty_instance(ctx: Context, expr: ast.ExprReference): ty.Instance
	local class: ty.StringLiteral?
	local parameters = expr.generics
	if parameters then
		local values = parameters.values
		if #values > 1 then
			return report.extra_generics(parameters, 1)
		end

		class = expression(ctx, values[1]) :: ty.StringLiteral
	end

	return ty.instance(expr, class)
end

local function ty_streamed_instance(ctx: Context, expr: ast.ExprReference): ty.StreamedInstance
	local class: ty.StringLiteral?
	local parameters = expr.generics
	if parameters then
		local values = parameters.values
		if #values > 1 then
			return report.extra_generics(parameters, 1)
		end

		class = expression(ctx, values[1]) :: ty.StringLiteral
	end

	return ty.streamed_instance(expr, class)
end

local PRIMITIVE_BUILDERS: { [string]: ((ctx: Context, expr: ast.ExprReference, path: string) -> Ty)? } = {
	u8 = ty_numeral,
	u16 = ty_numeral,
	u24 = ty_numeral,
	u32 = ty_numeral,
	u48 = ty_numeral,
	i8 = ty_numeral,
	i16 = ty_numeral,
	i24 = ty_numeral,
	i32 = ty_numeral,
	i48 = ty_numeral,
	f32 = ty_numeral,
	f64 = ty_numeral,
	string = ty_string,
	buffer = ty_buffer,
	vector = ty_vector,
	boolean = ty_boolean,
	unknown = ty_unknown,
	Enum = ty_roblox_enum,
	CFrame = ty_cframe,
	Instance = ty_instance,
	StreamedInstance = ty_streamed_instance,
	Color3 = ty_color3,
	DateTime = ty_date_time,
	BrickColor = ty_brick_color,
	DateTimeMillis = ty_date_time_millis,
}

local function ty_map(ctx: Context, expr: ast.ExprMap): ty.Map
	local index = expression(ctx, expr.index)
	local value = expression(ctx, expr.value)

	local range: SealedRange
	if expr.range then
		range = range_from_node(expr.range, bounds.map)
	end

	return ty.map(expr, index, value, range)
end

local function ty_array(ctx: Context, expr: ast.ExprArray): ty.Array
	local of = expression(ctx, expr.value)
	local size: SealedRange?
	if expr.range then
		size = range_from_node(expr.range, bounds.array)
	end

	return ty.array(expr, of, size)
end

local function ty_field(ctx: Context, expr: ast.ExprField): ty.Field
	local name = expr.name.value
	local value = expression(ctx, expr.value)
	return ty.field(expr, name, value)
end

local function ty_struct(ctx: Context, expr: ast.ExprStruct): ty.Struct
	local fields = table.create(#expr.fields) :: { ty.Field }
	local field_set: { [string]: ast.ExprField? } = {}
	for index, field in expr.fields do
		local name = field.name.value
		local previous = field_set[name]
		if previous ~= nil then
			report.duplicate_entry(previous.name, field.name, expr)
		end

		fields[index] = ty_field(ctx, field)
		field_set[name] = field
	end

	return ty.struct(expr, fields)
end

local function ty_union(ctx: Context, expr: ast.ExprUnion): ty.Union
	local components = {}
	for index, component_expr in expr.components do
		components[index] = expression(ctx, component_expr)
	end

	return ty.union(expr, components)
end

local function ty_optional(ctx: Context, expr: ast.ExprOptional): ty.Union
	local of = expression(ctx, expr.value)
	return ty.union(expr, { of, ty.nnil(expr) })
end

local function ty_discriminated_union(ctx: Context, expr: ast.ExprDiscriminatedUnion): ty.DiscriminatedUnion
	local tag = expr.tag.value
	local variants: { ty.Variant } = {}
	local variants_set: { [index<ast.ExprLiteral, "value">]: ast.ExprDiscriminatedUnionVariant? } = {}

	for index, variant_node in expr.variants do
		local key_node = variant_node.key
		local previous = variants_set[key_node.value]
		if previous ~= nil then
			report.duplicate_entry(previous.key, key_node, expr)
		end

		local value_node = variant_node.value
		for _, field in value_node.fields do
			if field.name.value == tag then
				report.tag_in_variant(expr.tag, field)
			end
		end

		local key_ty = expression(ctx, key_node) :: ty.Literal
		local value_ty = ty_struct(ctx, value_node)
		local variant_ty = ty.variant(variant_node, key_ty, value_ty)

		-- add tag field to variant struct
		local struct = variant_ty.value
		table.insert(struct.fields, 1, ty.field(key_node :: ast.Expression, tag, key_ty))

		variants[index] = variant_ty
		variants_set[key_node.value] = variant_node
	end

	return ty.discriminated_union(expr, tag, variants)
end

--- Returns the `ty_id` of the `ty` referenced
local function ty_reference(ctx: Context, expr: ast.ExprReference): Ty
	--[[
        Phases:
        1 - Check if the reference is a generic parameter, return the generic parameter if it is, otherwise Continue
        2 - Check whether the reference exists, continue if it does, otherwise report an unknown reference
        3 - If any arguments were passed alongside the reference convert them into an array of corresponding TyIds
        4 - If any arguments were passed then check whether the referenced Ty has parameters, if it does then continue to 5.1, else report extra arguments
        4.1 - Validate whether the exact amount of arguments were passed, report too few or too many if not, else create a new type function Ty and return it
        5 - Return a reference to a Ty
    --]]

	-- Phase 1:
	if ctx.generics then
		local path_string = path_node_to_string(expr.path)
		local generic_ty = ctx.generics.by_name[path_string]
		if generic_ty then
			return generic_ty
		end
	end

	-- Phase 2:
	local path_segments = path_node_to_segments(expr.path)
	local referenced_node = symbols.search(ctx.symbols, path_segments)
	if referenced_node == nil or referenced_node.kind ~= "type" then
		return report.unknown_reference(expr)
	end

	-- Phase 3:
	local arguments: { Ty } = {}
	local expr_arguments = expr.generics
	if expr_arguments then
		for index, value in expr_arguments.values do
			arguments[index] = expression(ctx, value)
		end
	end

	local reference_decl_id = referenced_node.id :: DeclId
	local reference_type_decl = lookup.decl_from_id(ctx.hir, reference_decl_id) :: types.Type

	-- Phase 4:
	local reference_parameters = reference_type_decl.generics
	if reference_parameters then
		-- Phase 4.1:
		local n_parameters = #reference_parameters
		if expr_arguments == nil then
			return report.few_none_generics(expr.path, n_parameters)
		end

		local n_arguments = #expr_arguments.values
		if n_arguments > n_parameters then
			return report.extra_generics(expr_arguments, n_parameters)
		elseif n_arguments < n_parameters then
			return report.few_generics(expr_arguments, n_parameters)
		end
	elseif expr_arguments then
		return report.extra_generics(expr_arguments, 0)
	end

	-- Phase 5:
	return ty.reference(expr, reference_type_decl.ty_id, arguments)
end

function expression(ctx: Context, expr: ast.Expression | ast.Identifier, generics: Generics?): Ty
	store_node(ctx.hir, expr)

	if generics ~= nil then
		ctx.generics = generics
	end

	--> process node
	local tty: Ty
	if expr.kind == "map" then
		tty = ty_map(ctx, expr)
	elseif expr.kind == "array" then
		tty = ty_array(ctx, expr)
	elseif expr.kind == "union" then
		tty = ty_union(ctx, expr)
	elseif expr.kind == "string" then
		tty = ty_string_literal(ctx, expr)
	elseif expr.kind == "struct" then
		tty = ty_struct(ctx, expr)
	elseif expr.kind == "number" then
		tty = ty_number_literal(ctx, expr)
	elseif expr.kind == "boolean" then
		tty = ty_boolean_literal(ctx, expr)
	elseif expr.kind == "discriminated_union" then
		tty = ty_discriminated_union(ctx, expr)
	elseif expr.kind == "optional" then
		tty = ty_optional(ctx, expr)
	elseif expr.kind == "reference" then
		local path_str = path_node_to_string(expr.path)
		local primitive = PRIMITIVE_BUILDERS[path_str]
		tty = if primitive then primitive(ctx, expr, path_str) else ty_reference(ctx, expr)
	elseif expr.kind == "identifier" then
		tty = ty_string_literal(ctx, expr :: any)
	elseif expr.kind == "field" or expr.kind == "variant" then
		panic(`Got a contextual expression kind "{expr.kind}" in a non contextual location`)
	else
		return strong_exhaustive_match(expr.kind)
	end

	if generics then
		ctx.generics = nil
		tty = ty.type_function(expr :: ast.Expression, tty, generics.parameters)
	end

	return tty
end

local function expr_pack(ctx: Context, expr: ast.ExprPack): { types.Parameter }
	local parameters: { types.Parameter } = {}
	for index, expr in expr.values do
		local name = if expr.name then expr.name.value else nil
		local tty = expression(ctx, expr.value)

		local expr_node_id = store_node(ctx.hir, expr :: any)
		local ty_id = expr_node_id :: TyId
		ctx.hir.tys[ty_id] = tty

		local parameter: types.Parameter = {
			name = name,
			ty_id = ty_id,
		}

		table.insert(parameters, parameter)
	end

	return parameters
end

local function switch_scope(ctx: Context, scope_id: ScopeId)
	if scope_id ~= ctx.scope_id then
		ctx.scope_id = scope_id
		ctx.symbols = ctx.hir.scopes[scope_id].symbols
	end
end

local function build_tys(ctx: Context, collection: Collection)
	local hir = ctx.hir

	for _, decl_type in collection.types do
		local ty_id = decl_type.id :: TyId
		local node_id = decl_type.id :: NodeId
		local type_stat = lookup.node_from_id(hir, node_id) :: ast.StatType

		local generics: Generics?
		local type_parameters = decl_type.generics
		if type_parameters then
			local by_name_map = {}
			for index, generic in type_parameters do
				by_name_map[generic.name] = generic
			end

			generics = {
				by_name = by_name_map,
				parameters = type_parameters,
			}
		end

		switch_scope(ctx, decl_type.scope_id)
		hir.tys[ty_id] = expression(ctx, type_stat.value, generics)
	end

	for _, decl_event in collection.events do
		local node = lookup.node_from_id(hir, decl_event.id :: NodeId) :: ast.StatEvent
		if node.data == nil then
			continue
		end

		switch_scope(ctx, decl_event.scope_id)
		decl_event.data = expr_pack(ctx, node.data)
	end

	for _, decl_funct in collection.functs do
		local node = lookup.node_from_id(hir, decl_funct.id :: NodeId) :: ast.StatFunction
		if node.data ~= nil then
			switch_scope(ctx, decl_funct.scope_id)
			decl_funct.data = expr_pack(ctx, node.data)
		end

		if node.ret ~= nil then
			switch_scope(ctx, decl_funct.scope_id)
			decl_funct.ret = expr_pack(ctx, node.ret)
		end
	end
end

--[=[
    Constructs a HIR from the provided files map.
    @param `files` - A map of `file_id` to an `AST`. A `file_id` of **0** must always correspond to the **entry file**.
]=]
local function from_files(files: compilation.FilesMap): Hir
	local hir: Hir = {
		tys = {},
		nodes = {},

		types = {},
		events = {},
		functs = {},
		scopes = {},

		options = {},
	}

	-- traverse file asts
	local collections: { [number]: Collection } = {}
	for file_id, file_ast in files do
		local collection = collect_decls(hir, file_id, file_ast)
		collections[file_id] = collection
	end

	for file_id, collection in collections do
		local file_ast = files[file_id]

		local scope_id = file_ast.body.id :: ScopeId
		local root_symbols = file_ast.symbols

		local context: Context = {
			hir = hir,

			options = {},
			options_declarations = {},

			symbols = root_symbols,
			scope_id = scope_id,
		}

		build_tys(context, collection)
	end

	return hir
end

return table.freeze({
	from_files = from_files,
})
