--!strict
--!native
--!optimize 2

local id = require("@compiler/id")
local ty = require("@compiler/structures/ty")
local hir = require("@compiler/structures/hir")
local ast = require("@compiler/structures/ast")

local codes = require("@compiler/config/codes")
local bounds = require("@compiler/config/bounds")
local primitives = require("@compiler/config/primitives")

local fmt_range = require("@format/range")

local span = require("@util/span")
local range = require("@util/range")
local panic = require("@util/panic")
local symbols = require("@util/symbols")
local diagnostics = require("@util/diagnostics")

type Ty = ty.Ty
type Decl = hir.Decl
type Node = ast.Node

type Hir = hir.Hir
type Ast = ast.Ast

type TyId<T = Ty> = ty.TyId
type DeclId<T = Decl> = hir.DeclId<T>
type NodeId<T = Node> = ast.NodeId<T>
type ScopeId = hir.ScopeId

type TyKind = ty.TyKind

type Range = range.Range

type Context = {
    read hir: Hir,
    read ast: Ast,

    scope: ScopeId,
    node_id: number,
    symbols: ast.Symbols,
    generics: {
        args: {TyId<ty.Placeholder>},
        values: {[string]: TyId<ty.Placeholder>}
    }?,
}

local DUMMY_ID = ast.DUMMY_ID
local ROOT_SCOPE = id.node_id.to_scope_id(DUMMY_ID :: any)

local block: (ctx: Context, node: ast.Block) -> ()
local statement: (ctx: Context, stat: ast.Statement) -> DeclId?
local expression: (ctx: Context, expr: ast.Expression) -> TyId

local function report_expect(node: {span: span.Span}, expected: string, got: string): never
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.InvalidType)
        .with_message(`Expected "{expected}", got "{got}" instead`)
        .with_label(diagnostics.label.create(node.span)
            .with_message(`Expected "{expected}"`)
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_expect_one_of(node: {span: span.Span}, expected: {string}, got: string): never
    local fmted_expected = `"{table.concat(expected, "\", \"")}"`
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.InvalidType)
        .with_message(`Expected one of {fmted_expected}, got "{got}" instead`)
        .with_label(diagnostics.label.create(node.span)
            .with_message(`Expected one of {fmted_expected}`)
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_few_none_generics(node: ast.Path, expected: number): never
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.ExtraGenericsParameters)
        .with_message(`Type expects {expected} generic parameter(s), but none are specified`)
        .with_label(diagnostics.label.create(node.span)
            .with_message(`Add missing generic parameters list`)
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_few_generics(node: ast.GenericsArgs, expected: number): never
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.ExtraGenericsParameters)
        .with_message(`Type expects {expected} generic parameter(s), but {#node.values} are specified`)
        .with_label(diagnostics.label.create(node.span)
            .with_message(`Add missing generic parameters`)
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_extra_generics(node: ast.GenericsArgs, maximum: number): never
    local values = node.values
    local first_extra = values[maximum + 1]
    local final_extra = values[#values]
    local extras_span = span.merge(first_extra.span, final_extra.span)

    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.ExtraGenericsParameters)
        .with_message(`Type expects {maximum} generic parameter(s), but {#values} are specified`)
        .with_label(diagnostics.label.create(extras_span)
            .with_message(`Remove extra generic parameters`)
            .with_color(diagnostics.style.color.red)
        )
        .finish()
    .error()
end

local function report_unknown_reference(expr: ast.ExprReference): never
    local name = expr.name
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.UnknownReference)
        .with_message(`Unknown reference "{name.value}"`)
        .with_label(diagnostics.label.create(name.span)
            .with_color(diagnostics.style.color.red)
            .with_message(`Unknown reference`)
        )
    .finish()
    .error()
end

local function report_unrepresentable_range(node: ast.Range, bounds: Range): never
    return diagnostics.report.create("Error")
        .with_code(codes.type_checking.UnrepresentableRange)
        .with_message("Range cannot be represented by the type")
        .with_label(diagnostics.label.create(node.span)
            .with_color(diagnostics.style.color.red)
            .with_message(`Range should be within {fmt_range(bounds)}`)
        )
    .finish()
    .error()
end

local function ty_from_id(ctx: Context, ty_id: TyId): Ty
    local ty = ctx.hir.tys[ty_id]
    if ty == nil then
        return panic("Expected ty_id to point to a ty")
    end

    return ty
end

local function decl_from_id(ctx: Context, decl_id: DeclId): Decl
    local decl = ctx.hir.decls[decl_id]
    if decl == nil then
        return panic("Expected decl_id to point to a decl")
    end

    return decl
end

local function node_from_id(ctx: Context, node_id: NodeId): Node
    local node = ctx.hir.nodes[node_id]
    if node == nil then
        return panic("Expected node_id to point to a node")
    end

    return node
end

local function node_from_ty_id(ctx: Context, ty_id: TyId): Node
    local node_id = id.ty_id.to_node_id(ty_id)
    return node_from_id(ctx, node_id)
end

local function next_node_id<T>(ctx: Context): NodeId<T>
    local id = ctx.node_id
    ctx.node_id += 1
    return id :: any
end

local function assign_node_id(ctx: Context, node: Node): NodeId
    local node_id = next_node_id(ctx)
    node.id = node_id
    ctx.hir.nodes[node_id] = node
    return node_id
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

local function path_to_array(path: ast.Path): {string}
    local segments: {string} = {}
    for _, segment in path.segments do
        table.insert(segments, segment.value)
    end

    return segments
end

local function path_to_string(path: ast.Path): string
    return table.concat(path_to_array(path), ".")
end

local function assert_identifier_one_of(ctx: Context, ident: ast.Identifier, valid: {string}): ast.Identifier
    local value = ident.value
    if table.find(valid, value) == nil then
        --TODO: Remove cast when Luau solver bug is fixed
        return report_expect_one_of(ident :: any, valid, value)
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
        return report_unrepresentable_range(node, bounds)
    end

    return range.create(min, max)
end

--> Luau Primitives

local function prim_number(ctx: Context, identifier: string, expr_range: ast.Range?): ty.Numeral
    local numeral: primitives.Primitive = (primitives :: any)[identifier]

    local size: ty.NumSize = string.sub(identifier, 2, 3) :: ty.NumSize
    local format: ty.NumFormat = string.sub(identifier, 1, 1) :: ty.NumFormat
    local range: Range?;

    if expr_range then
        range = range_node_to_range_class(
            expr_range, 
            numeral.range or primitives.f64.range
        )
    end
    
    return {
        kind = "numeral",
        size = size,
        format = format,
        bounds = range
    }
end

local function prim_string(ctx: Context, expr_range: ast.Range?): ty.String
    local bounds = primitives.string.range
    local range = if expr_range then range_node_to_range_class(expr_range, bounds) else nil

    return {
        kind = "string",
        length = range
    }
end

local function prim_buffer(ctx: Context, expr_range: ast.Range?): ty.Buffer
    local bounds = primitives.buffer.range
    local range = if expr_range then range_node_to_range_class(expr_range, bounds) else nil

    return {
        kind = "buffer",
        length = range
    }
end

local function prim_vector(ctx: Context, expr: ast.ExprReference): ty.Vector
    local expr_range = expr.range
    local expr_generics = expr.generics

    local range: Range?;
    if expr_range then
        range = range_node_to_range_class(expr_range, primitives.vector.range)
    end

    local axes: {TyId<ty.Numeral>} = {}
    if expr_generics then
        local values = expr_generics.values
        if #values > 3 then
            return report_extra_generics(expr_generics, 3)
        end

        for index, value in values do
            axes[index] = expression(ctx, value)
        end
    end

    return {
        kind = "vector",
        x = axes[1],
        y = axes[2],
        z = axes[3],
        magnitude = range
    }
end

local function prim_boolean(ctx: Context): ty.Boolean
    return {
        kind = "boolean"
    }
end

local function prim_unkown(ctx: Context): ty.Unknown
    return {
        kind = "unknown"
    }
end

--> ROBLOX Primitives

local function prim_enum(ctx: Context, expr_generics: ast.GenericsArgs?): ty.Enum
    local enum_type: TyId<ty.StringLiteral>?
    if expr_generics then
        local values = expr_generics.values
        if #values > 1 then
            return report_extra_generics(expr_generics, 1)
        end

        local generic = values[1]
        enum_type = expression(ctx, generic)
    end

    return {
        kind = "roblox_enum",
        type = enum_type
    }
end

local function prim_color3(ctx: Context): ty.Color3
    return {
        kind = "color3",
    }
end

local function prim_cframe(ctx: Context, expr_generics: ast.GenericsArgs?): ty.CFrame
    local generics: {TyId<ty.Numeral>} = {}
    if expr_generics then
        local values = expr_generics.values
        if #values > 2 then
            return report_extra_generics(expr_generics, 2)
        end

        for index, value in values do
            local ty_id = expression(ctx, value)
            generics[index] = ty_id
        end
    end

    return {
        kind = "cframe",
        position = generics[1],
        rotation = generics[2]
    }
end

local function prim_date_time(ctx: Context): ty.DateTime
    return {
        kind = "date_time",
    }
end

local function prim_date_time_millis(ctx: Context): ty.DateTimeMillis
    return {
        kind = "date_time_millis",
    }
end

local function prim_brick_color(ctx: Context): ty.BrickColor
    return {
        kind = "brick_color",
    }
end

local function prim_instance(ctx: Context, expr_generics: ast.GenericsArgs?): ty.Instance
    local class_name: TyId<ty.StringLiteral>?
    if expr_generics then
        local values = expr_generics.values
        if #values > 1 then
            return report_extra_generics(expr_generics, 1)
        end

        class_name = expression(ctx, values[1])
    end

    return {
        kind = "instance",
        class = class_name
    }
end

local function prim_ty_from_ref(ctx: Context, expr: ast.ExprReference, path: string): Ty
    if 
        path == "u8" or path == "u16" or path == "u32" or path == "u48" 
        or path == "i8" or path == "i16" or path == "i32" or path == "i48" 
        or path == "f16" or path == "f32" or path == "f64"
    then
        return prim_number(ctx, path, expr.range)
    elseif path == "string" then
        return prim_string(ctx, expr.range)
    elseif path == "buffer" then
        return prim_buffer(ctx, expr.range)
    elseif path == "vector" then
        return prim_vector(ctx, expr)
    elseif path == "boolean" then
        return prim_boolean(ctx)
    elseif path == "unknown" then
        return prim_unkown(ctx)
    elseif path == "Enum" then
        return prim_enum(ctx, expr.generics)
    elseif path == "CFrame" then
        return prim_cframe(ctx, expr.generics)
    elseif path == "Instance" then
        return prim_instance(ctx, expr.generics)
    elseif path == "Color3" then
        return prim_color3(ctx)
    elseif path == "DateTime" then
        return prim_date_time(ctx)
    elseif path == "BrickColor" then
        return prim_brick_color(ctx)
    elseif path == "DateTimeMillis" then
        return prim_date_time_millis(ctx)
    end

    return panic(`Unhandled primitive "{path}"`)
end

local function expr_set(ctx: Context, expr: ast.ExprSet): ty.Set
    local items: {string} = {}
    for _, value in expr.values do
        table.insert(items, value.value)
    end

    return {
        kind = "set",
        items = items
    }
end

local function expr_map(ctx: Context, expr: ast.ExprMap): ty.Map
    local index = expression(ctx, expr.index)
    local value = expression(ctx, expr.value)

    local range: Range;
    if expr.range then
        range = range_node_to_range_class(
            expr.range, 
            bounds.map
        )
    end

    return {
        kind = "map",
        index = index,
        value = value,
        range = range
    }
end

local function expr_enum(ctx: Context, expr: ast.ExprEnum): ty.UnitEnum
    local variants: {string} = {}
    for _, variant in expr.variants do
        table.insert(variants, variant.value)
    end

    return {
        kind = "enum",
        variants = variants
    }
end

local function expr_array(ctx: Context, expr: ast.ExprArray): ty.Array
    local ty_id = expression(ctx, expr.value)
    local range = range_node_to_range_class(expr.range, bounds.array)

    return {
        kind = "array",
        of = ty_id,
        size = range,
    }
end

local function expr_union(ctx: Context, expr: ast.ExprUnion): ty.Union
    local left_ty_id = expression(ctx, expr.left)
    local right_ty_id = expression(ctx, expr.right)

    return {
        kind = "union",
        left = left_ty_id,
        right = right_ty_id
    }
end

local function expr_field(ctx: Context, expr: ast.ExprField): ty.Field
    local name = expr.name.value
    local value = expression(ctx, expr.value)

    return {
        kind = "field",
        name = name,
        value = value
    }
end

local function expr_struct(ctx: Context, expr: ast.ExprStruct): ty.Struct
    local fields: {ty.Field} = {}
    for index, field in expr.fields do
        fields[index] = expr_field(ctx, field)
    end

    return {
        kind = "struct",
        fields = fields
    }
end

local function expr_string(ctx: Context, expr: ast.ExprString): ty.StringLiteral
    return {
        kind = "string_literal",
        value = expr.value
    }
end

local function expr_number(ctx: Context, expr: ast.ExprNumber): ty.NumberLiteral
    return {
        kind = "number_literal",
        value = expr.value
    }
end

local function expr_boolean(ctx: Context, expr: ast.ExprBoolean): ty.BooleanLiteral
    return {
        kind = "boolean_literal",
        value = expr.value
    }
end

local function expr_optional(ctx: Context, expr: ast.ExprOptional): ty.Optional
    local ty_id = expression(ctx, expr.value)
    return {
        kind = "optional",
        of = ty_id
    }
end

local function expr_tagged_enum(ctx: Context, expr: ast.ExprTaggedEnum): ty.TaggedEnum
    local tag = expr.tag.value
    local variants: {ty.Variant} = {}
    for index, variant in expr.variants do
        local key = variant.key.value
        local value = expr_struct(ctx, variant.value)

        variants[index] = {
            kind = "variant",
            key = key,
            value = value
        }
    end

    return {
        kind = "tagged_enum",
        tag = tag,
        variants = variants
    }
end

local function expr_generic_type(ctx: Context, ty: Ty, args: {ty.TyId<ty.Placeholder>}): ty.GenericType
    return {
        kind = "generic_type",
        ty = ty,
        args = args
    }
end

local function expr_reference(ctx: Context, expr: ast.ExprReference): TyId
    if ctx.generics then
        local path = path_to_string(expr.path)
        local placeholder = ctx.generics.values[path]
        if placeholder then
            return placeholder
        end
    end

    local node = symbols.search(ctx.ast.symbols, path_to_array(expr.path))
    if node == nil or node.kind ~= "type" then
        return report_unknown_reference(expr)
    end

    local node_id = node.id
    local decl_id = id.node_id.to_decl_id(node_id)
    local decl: hir.Type = decl_from_id(ctx, decl_id) :: any

    local expr_generics = expr.generics
    local decl_generics = decl.generics

    if decl_generics then
        local n_decl_generics = #decl_generics
        if expr_generics == nil then
            return report_few_none_generics(expr.path, n_decl_generics)
        end

        local n_expr_generics = #expr_generics.values
        if n_expr_generics > n_decl_generics then
            return report_extra_generics(expr_generics, n_decl_generics)
        elseif n_expr_generics < n_decl_generics then
            return report_few_generics(expr_generics, n_decl_generics)
        end

        local ty_id = id.node_id.to_ty_id(node_id)
        local decl_ty = ty_from_id(ctx, decl.ty) :: ty.GenericType

        local args: {TyId} = {}
        for index, generic in expr_generics.values do
            args[index] = expression(ctx, generic)
        end
        
        local ty: ty.GenericType = expr_generic_type(ctx, decl_ty.ty, args)
        ctx.hir.tys[ty_id] = ty

        return ty_id
    elseif expr_generics then
        return report_extra_generics(expr_generics, 0)
    end
    
    return decl.ty
end

function expression(ctx: Context, expr: ast.Expression): TyId
    --> assign node_id
    local node_id = assign_node_id(ctx, expr)
    local ty_id = id.node_id.to_ty_id(node_id)

    --> process node
    local ty: Ty;
    if expr.kind == "set" then
        ty = expr_set(ctx, expr)
    elseif expr.kind == "map" then
        ty = expr_map(ctx, expr)
    elseif expr.kind == "enum" then
        ty = expr_enum(ctx, expr)
    elseif expr.kind == "array" then
        ty = expr_array(ctx, expr)
    elseif expr.kind == "union" then
        --TODO: Remove cast when Luau bug is fixed
        ty = expr_union(ctx, expr) :: Ty
    elseif expr.kind == "string" then
        ty = expr_string(ctx, expr)
    elseif expr.kind == "struct" then
        ty = expr_struct(ctx, expr)
    elseif expr.kind == "number" then
        ty = expr_number(ctx, expr)
    elseif expr.kind == "boolean" then
        --TODO: Remove cast when Luau bug is fixed
        ty = expr_boolean(ctx, expr :: any)
    elseif expr.kind == "tag_enum" then
        --TODO: Remove cast when Luau bug is fixed
        ty = expr_tagged_enum(ctx, expr :: any)
    elseif expr.kind == "optional" then
        --TODO: Remove cast when Luau bug is fixed
        ty = expr_optional(ctx, expr :: any)
    elseif expr.kind == "reference" then
        --TODO: Remove when Luau bug is fixed
        expr = (expr :: any) :: ast.ExprReference

        local path = path_to_string(expr.path)
        local primitive = (primitives :: any)[path]
        if primitive == nil then
            return expr_reference(ctx, expr)
        end

        ty = prim_ty_from_ref(ctx, expr, path)
    else
        panic(`Unhandled expression "{expr.kind}"`)
    end

    if ctx.generics then
        ty = expr_generic_type(ctx, ty, ctx.generics.args)
    end

    --> store ty
    ctx.hir.tys[ty_id] = ty

    return ty_id
end

local function expr_pack(ctx: Context, expr: ast.ExprPack): {hir.Parameter}
    local parameters: {hir.Parameter} = {}
    for index, expr in expr.values do
        local name = if expr.name then expr.name.value else nil
        local value = expression(ctx, expr.value)
        local parameter: hir.Parameter = {
            name = name,
            value = value
        }

        table.insert(parameters, parameter)
    end

    return parameters
end

local function stat_type(ctx: Context, stat: ast.StatType): hir.Type
    local scope = ctx.scope

    --> set generics
    local args: {TyId<ty.Placeholder>}?;
    local generics = stat.generics

    if generics then
        local values: {[string]: TyId<ty.Placeholder>} = {}
        args = {}

        for index, generic in generics.values do
            local name = generic.name
            local node_id = assign_node_id(ctx, generic)
            local ty_id = id.node_id.to_ty_id(node_id)

            local placeholder: ty.Placeholder = {
                kind = "placeholder",
                name = name.value,
                index = index
            }

            ctx.hir.tys[ty_id] = placeholder

            args[index] = ty_id
            values[name.value] = ty_id
        end

        ctx.generics = {
            args = args,
            values = values
        }
    end

    --> lower expression
    local ty_id = expression(ctx, stat.value)

    --> remove generics
    ctx.generics = nil

    return {
        kind = "type",
        name = stat.name.value,
        scope = scope,

        ty = ty_id,
        generics = args
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
    local from = assert_identifier_one_of(ctx, stat.from, {"Client", "Server", "Both"}).value
    local call = assert_identifier_one_of(ctx, stat.call, {"ManySync", "SingleSync", "ManyAsync", "SingleAsync"}).value
    local poll = if stat.poll then stat.poll.value else false
    local data = if stat.data then expr_pack(ctx, stat.data) else nil
    local reliability = assert_identifier_one_of(ctx, stat.type, {"Reliable", "Unreliable"}).value

    return {
        kind = "event",
        scope = ctx.scope,

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
    local yield = assert_identifier_one_of(ctx, stat.yield, {"Coroutine", "Promise", "Future"}).value
    local data = if stat.data then expr_pack(ctx, stat.data) else nil
    local ret = if stat.ret then expr_pack(ctx, stat.ret) else nil

    return {
        kind = "function",
        scope = ctx.scope,

        name = name,
        yield = yield :: any,
        data = data,
        ret = ret
    }
end

function statement(ctx: Context, stat: ast.Statement): DeclId?
    --> assign node_id
    local node_id = assign_node_id(ctx, stat)

    --> process node
    local decl: Decl?;
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

local function lower_ast_to_hir(ast: Ast): Hir
    local hir: Hir = {
        tys = {},
        decls = {},
        nodes = {},
        scopes = {},
    }

    local context: Context = {
        hir = hir,
        ast = ast,

        scope = ROOT_SCOPE,
        node_id = (DUMMY_ID + 1),
        symbols = ast.symbols,

        nodes = {},
        generics = nil :: any
    }

    --> traverse the ast
    block(context, ast.body)

    return hir
end

return table.freeze({
    lower_ast_to_hir = lower_ast_to_hir
})