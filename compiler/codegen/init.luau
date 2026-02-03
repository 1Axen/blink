--!strict
--!native
--!optimize 2

local append_buffer_fns = require("@codegen/templates/append_buffer_fns")
local append_client = require("@codegen/templates/append_client")
local append_headers = require("@self/templates/append_headers")
local append_server = require("@codegen/templates/append_server")
local compilation = require("@config/compilation")
local context = require("@self/context")
local id = require("@compiler/id")

local append_luau_type = require("@self/append_luau_type")
local assert_panic = require("@util/assert_panic")
local cased_method = require("@self/cased_method")
local constant = require("@lir/build/builders/constant")
local globals = require("@lir/build/builders/globals")
local hir = require("@hir")
local lir = require("@compiler/lir")
local md5 = require("@vendor/md5")
local options = require("@config/options")
local panic = require("@util/panic")
local string_builder = require("@util/string_builder")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local weak_exhaustive_match = require("@util/weak_exhaustive_match")

type Hir = hir.Hir
type Casing = cased_method.Casing
type Context = context.Context

local gen_lvalue: <T>(ctx: Context, lvalue: lir.LValue<T>) -> ()
local gen_rvalue: <T>(ctx: Context, rvalue: lir.RValue<T>) -> ()
local gen_anon_fn: (ctx: Context, anon_fn: lir.AnonymousFn) -> ()
local gen_fn: (ctx: Context, fn: lir.Fn) -> ()

local EVENT_GLOBALS = globals.events
local RELIABLE_EVENT = EVENT_GLOBALS.reliable.identifier
local UNRELIABLE_EVENT = EVENT_GLOBALS.unreliable.identifier

local function gen_constant(ctx: Context, constant: lir.Constant)
	ctx.builder:append(tostring(constant.value))
end

local function gen_constant_with_qoutes(ctx: Context, constant: lir.Constant)
	local builder = ctx.builder
	if type(constant.value) == "string" then
		builder:append(`'{constant.value}'`)
		return
	end

	builder:append(tostring(constant.value))
end

local function gen_projection<T>(ctx: Context, projection: lir.Projection<T>)
	local builder = ctx.builder
	local base = projection.base
	if base.type == "constant" then
		gen_constant(ctx, base)
	else
		gen_lvalue(ctx, base)
	end

	if projection.kind == "call" then
		builder:append("(")
		for index, argument in projection.args do
			if index > 1 then
				builder:append(", ")
			end

			gen_rvalue(ctx, argument)
		end
		builder:append(")")
	elseif projection.kind == "index" then
		builder:append(".")
		gen_constant(ctx, projection.element)
	elseif projection.kind == "field" then
		builder:append("[")
		gen_rvalue(ctx, projection.field)
		builder:append("]")
	elseif projection.kind == "namecall" then
		builder:append(":")
		gen_constant(ctx, projection.method)
		builder:append("(")
		for index, argument in projection.args do
			if index > 1 then
				builder:append(", ")
			end

			gen_rvalue(ctx, argument)
		end
		builder:append(")")
	else
		weak_exhaustive_match(projection.kind)
	end
end

local function gen_id<T>(ctx: Context, id: lir.Id<T>): never?
	local builder = ctx.builder
	if id.kind == "register" then
		builder:append(`r{id.index}`)
	elseif id.kind == "parameter" then
		local fn = ctx.current_fn
		if fn == nil then
			return panic(`expected a current fn`)
		end

		local index = id.index
		local parameter = fn.params[index]
		builder:append(parameter.name or `p{index}`)
	else
		strong_exhaustive_match(id.kind)
	end

	return nil
end

local function gen_global(ctx: Context, global: lir.Global<any>)
	ctx.builder:append(global.identifier)
end

function gen_lvalue(ctx: Context, lvalue: lir.LValue<any>)
	if lvalue.type == "id" then
		gen_id(ctx, lvalue)
	elseif lvalue.type == "global" then
		gen_global(ctx, lvalue)
	elseif lvalue.type == "projection" then
		gen_projection(ctx, lvalue)
	else
		strong_exhaustive_match(lvalue.type)
	end
end

local function gen_control(ctx: Context, control: lir.Control<any>)
	local builder = ctx.builder
	if control.kind == "advance" then
		builder:append("advance(")
		gen_rvalue(ctx, control.bytes)
		builder:append(")")
	elseif control.kind == "allocate" then
		builder:append("allocate(")
		gen_rvalue(ctx, control.bytes)
		builder:append(")")
	else
		strong_exhaustive_match(control.kind)
	end
end

local function gen_condition(ctx: Context, condition: lir.Condition<any>)
	gen_rvalue(ctx, condition.left)

	local builder = ctx.builder
	if condition.kind == "or" then
		builder:append(" or ")
	elseif condition.kind == "and" then
		builder:append(" and ")
	elseif condition.kind == "equals" then
		builder:append(" == ")
	elseif condition.kind == "not_equals" then
		builder:append(" ~= ")
	elseif condition.kind == "greater_than" then
		builder:append(" > ")
	elseif condition.kind == "greater_than_or" then
		builder:append(" >= ")
	elseif condition.kind == "less_than" then
		builder:append(" < ")
	elseif condition.kind == "less_than_or" then
		builder:append(" <= ")
	else
		strong_exhaustive_match(condition.kind)
	end

	gen_rvalue(ctx, condition.right)
end

local function gen_structure(ctx: Context, structure: lir.Structure<any>)
	local builder = ctx.builder

	builder:append("{")
	if structure.kind == "map" then
		for key, value in structure.values do
			builder:append("[")
			gen_rvalue(ctx, key)
			builder:append("] = ")
			gen_rvalue(ctx, value)
			builder:append(",")
		end
	elseif structure.kind == "array" then
		for _, value in structure.values do
			gen_rvalue(ctx, value)
			builder:append(",")
		end
	elseif structure.kind == "struct" then
		for field, value in structure.values do
			builder:append("[")
			gen_constant_with_qoutes(ctx, field)
			builder:append("] = ")
			gen_rvalue(ctx, value)
			builder:append(",")
		end
	end
	builder:append("}")
end

local function gen_binary_op(ctx: Context, binary: lir.BinaryOp<any>)
	local builder = ctx.builder
	builder:append("(")
	gen_rvalue(ctx, binary.left)

	if binary.kind == "add" then
		builder:append(" + ")
	elseif binary.kind == "sub" then
		builder:append(" - ")
	elseif binary.kind == "mul" then
		builder:append(" * ")
	elseif binary.kind == "mod" then
		builder:append(" % ")
	elseif binary.kind == "div" then
		builder:append(" / ")
	elseif binary.kind == "pow" then
		builder:append(" ^ ")
	elseif binary.kind == "idiv" then
		builder:append(" // ")
	else
		strong_exhaustive_match(binary.kind)
	end

	gen_rvalue(ctx, binary.right)
	builder:append(")")
end

local function gen_unary_op(ctx: Context, unary: lir.UnaryOp<any>)
	local builder = ctx.builder
	if unary.kind == "len" then
		builder:append("#")
	else
		strong_exhaustive_match(unary.kind)
	end

	gen_rvalue(ctx, unary.of)
end

local function gen_ternary(ctx: Context, ternary: lir.Ternary<any>)
	local builder = ctx.builder
	builder:append("if ")
	gen_condition(ctx, ternary.cond)
	builder:append(" then ")
	gen_rvalue(ctx, ternary.left)
	builder:append(" else ")
	gen_rvalue(ctx, ternary.right)
end

local function gen_cast(ctx: Context, cast: lir.Cast<any>)
	local builder = ctx.builder
	builder:append("(")
	gen_rvalue(ctx, cast.value)
	builder:append(" :: ")

	if cast.kind == "ty" then
		append_luau_type(ctx, cast.cast_to)
	elseif cast.kind == "static" then
		builder:append(cast.cast_to)
	else
		strong_exhaustive_match(cast.kind)
	end

	builder:append(")")
end

function gen_rvalue(ctx: Context, rvalue: lir.RValue<any>)
	if rvalue.type == "id" then
		gen_id(ctx, rvalue)
	elseif rvalue.type == "control" then
		gen_control(ctx, rvalue)
	elseif rvalue.type == "global" then
		gen_global(ctx, rvalue)
	elseif rvalue.type == "unary" then
		gen_unary_op(ctx, rvalue)
	elseif rvalue.type == "binary" then
		gen_binary_op(ctx, rvalue)
	elseif rvalue.type == "ternary" then
		gen_ternary(ctx, rvalue)
	elseif rvalue.type == "constant" then
		gen_constant_with_qoutes(ctx, rvalue)
	elseif rvalue.type == "condition" then
		gen_condition(ctx, rvalue)
	elseif rvalue.type == "projection" then
		gen_projection(ctx, rvalue)
	elseif rvalue.type == "structure" then
		gen_structure(ctx, rvalue)
	elseif rvalue.type == "anon_fn" then
		gen_anon_fn(ctx, rvalue)
	elseif rvalue.type == "cast" then
		gen_cast(ctx, rvalue)
	else
		weak_exhaustive_match(rvalue.type)
	end
end

local function gen_loop(ctx: Context, loop: lir.Loop)
	local builder = ctx.builder
	builder:append("for ")

	if loop.kind == "numeric" then
		context.try_see_register(ctx, loop.index)
		gen_id(ctx, loop.index)
		builder:append(" = 1, ")
		gen_rvalue(ctx, loop.iterations :: any)
	elseif loop.kind == "generic" then
		context.try_see_register(ctx, loop.index)
		gen_id(ctx, loop.index)
		builder:append(", ")
		context.try_see_register(ctx, loop.index)
		gen_id(ctx, loop.value)
		builder:append(" in ")
		gen_rvalue(ctx, loop.target :: any)
	else
		strong_exhaustive_match(loop.kind)
	end

	builder:append(" do\n")
end

local function gen_terminator(ctx: Context, terminator: lir.Terminator)
	local lirr = ctx.lir
	local builder = ctx.builder

	if terminator.kind == "if" then
		builder:append_indent()
		builder:append("if ")
		gen_condition(ctx, terminator.cond)
		builder:append(" then\n")

		builder:indent()
		context.push_block(ctx, terminator.falsey)
		context.push_block(ctx, terminator.truthy)
	elseif terminator.kind == "if_chain" then
		builder:append_line(
			`-- if ({terminator.chain_index}/{terminator.chain_length}) (bb{terminator.truthy.index}, bb{terminator.falsey.index})`
		)

		local scope = terminator.falsey.scope
		local chain_index = terminator.chain_index
		local chain_length = terminator.chain_length
		if chain_index == 1 and chain_length > 1 then
			ctx.if_chains[scope] = true
		elseif chain_index == terminator.chain_length then
			ctx.if_chains[scope] = nil
		end

		builder:append_indent()

		-- it's likely better to implement a proper way to represent the else case
		-- but this works for now
		local cond = terminator.cond
		if
			chain_index == chain_length
			and chain_index > 1
			and cond.left == constant.truth
			and cond.right == constant.truth
		then
			builder:append("else")
		else
			if chain_index == 1 then
				builder:append("if ")
			else
				builder:append("elseif ")
			end

			gen_condition(ctx, cond)
			builder:append(" then\n")
		end

		builder:indent()
		context.push_block(ctx, terminator.falsey)
		context.push_block(ctx, terminator.truthy)
	elseif terminator.kind == "call" then
		builder:append_indent()
		local fn = lir.fn_from_id(lirr, terminator.fn)
		for index, ret in terminator.rets do
			if index == 1 and context.try_see_register(ctx, ret) then
				builder:append("local ")
			elseif index > 1 then
				builder:append(", ")
			end

			gen_lvalue(ctx, ret)
		end

		if #terminator.rets > 0 then
			builder:append(" = ")
		end

		local name = assert_panic(fn.name, "cannot call an anonymous function")
		if name.type == "projection" then
			gen_projection(ctx, name :: any)
		elseif name.type == "constant" then
			builder:append(name.value)
		else
			strong_exhaustive_match(name.type)
		end

		builder:append("(")

		for index, argument in terminator.args do
			if index > 1 then
				builder:append(", ")
			end

			gen_rvalue(ctx, argument)
		end

		builder:append(")\n")
		context.push_block(ctx, terminator.destination)
	elseif terminator.kind == "goto" then
		local destination = terminator.destination
		builder:append_line(`-- goto (bb{destination.index})`)
		builder:dedent()

		if ctx.if_chains[destination.scope] then
			return
		end

		builder:append_line("end")
		context.push_block(ctx, destination)
	elseif terminator.kind == "none" then
	elseif terminator.kind == "loop" then
		builder:append_indent()
		gen_loop(ctx, terminator.loop)
		builder:indent()
		context.push_block(ctx, terminator.destination)
	elseif terminator.kind == "while" then
		builder:append_indent()
		builder:append("while ")
		gen_condition(ctx, terminator.cond)
		builder:append(" do\n")

		builder:indent()
		context.push_block(ctx, terminator.truthy)
	elseif terminator.kind == "return" then
		builder:append_indent()
		builder:append("return ")
		for index, value in terminator.values do
			if index > 1 then
				builder:append(", ")
			end
			gen_rvalue(ctx, value)
		end
		builder:append("\n")

		if #ctx.block_queue > 0 then
			builder:dedent()
			builder:append_line("end")
		end
	else
		weak_exhaustive_match(terminator.kind)
	end
end

local function gen_statement(ctx: Context, statement: lir.Statement)
	local builder = ctx.builder

	if statement.kind == "call" then
		builder:append_indent()
		gen_rvalue(ctx, statement.call :: any)
		builder:append("\n")
	elseif statement.kind == "assign" then
		builder:append_indent()
		gen_lvalue(ctx, statement.into)

		if statement.value then
			builder:append(" = ")
			gen_rvalue(ctx, statement.value)
		end
		builder:append("\n")
	elseif statement.kind == "local_assign" then
		builder:append_indent()
		builder:append("local ")

		local into = statement.into
		gen_id(ctx, into)
		ctx.seen_registers[into.index] = true

		if statement.value then
			builder:append(" = ")
			gen_rvalue(ctx, statement.value)
		end
		builder:append("\n")
	elseif statement.kind == "multi_assign" then
		builder:append_indent()
		builder:append("local ")

		local seen_registers = ctx.seen_registers
		for index, lvalue in statement.into do
			if index > 1 then
				builder:append(", ")
			end

			if lvalue.type == "id" and lvalue.kind == "register" then
				seen_registers[lvalue.index] = true
			end

			gen_lvalue(ctx, lvalue)
		end

		builder:append(" = ")
		gen_rvalue(ctx, statement.value)
		builder:append("\n")
	elseif statement.kind == "remark" then
		builder:append_line(`-- REMARK: {statement.text}`)
	else
		weak_exhaustive_match(statement.kind)
	end
end

local function gen_block(ctx: Context, block: lir.BasicBlock)
	local index = block.index
	local builder = ctx.builder

	ctx.current_block = block

	builder:append_line(`-- bb{index} \{`)
	for _, statement in block.statements do
		gen_statement(ctx, statement)
	end
	builder:append_line(`-- bb{index} \}`)

	gen_terminator(ctx, block.terminator)
end

local function gen_hint(ctx: Context, annotation: lir.Hint)
	local builder = ctx.builder
	if annotation.kind == "ty" then
		append_luau_type(ctx, annotation.ty)
	elseif annotation.kind == "static" then
		builder:append(annotation.static)
	elseif annotation.kind == "function" then
		builder:append("(")

		for index, parameter in annotation.parameters do
			if index > 1 then
				builder:append(", ")
			end

			if parameter.name then
				builder:append(parameter.name)
				builder:append(": ")
			end

			gen_hint(ctx, parameter.hint)
		end

		builder:append(") -> ")

		local returns = annotation.returns
		local wrap_in_parentheses = #returns ~= 1
		if wrap_in_parentheses then
			builder:append("(")
		end

		for index, rreturn in returns do
			if index > 1 then
				builder:append(", ")
			end

			gen_hint(ctx, rreturn.hint)
		end

		if wrap_in_parentheses then
			builder:append(")")
		end
	else
		strong_exhaustive_match(annotation.kind)
	end
end

local function gen_fn_body(ctx: Context, fn_body: lir.FnBody)
	local builder = ctx.builder

	local prev_fn = ctx.current_fn
	local prev_queue = ctx.block_queue
	local prev_filter = ctx.block_queue_filter

	ctx.block_queue = {}
	ctx.block_queue_filter = {}
	ctx.current_fn = fn_body
	table.clear(ctx.seen_registers)

	builder:append("(")

	for index, parameter in fn_body.params do
		if index > 1 then
			builder:append(", ")
		end

		builder:append(parameter.name or `p{index}`)
		builder:append(": ")
		gen_hint(ctx, parameter.hint)
	end

	builder:append("): (")

	for index, rreturn in fn_body.rets do
		if index > 1 then
			builder:append(", ")
		end

		gen_hint(ctx, rreturn.hint)
	end

	builder:append(") \n")
	builder:indent()

	-- generate blocks until none are left
	context.push_block(ctx, fn_body.blocks[1])

	while true do
		local block = context.pop_block(ctx)
		if block == nil then
			break
		end

		gen_block(ctx, block)
	end

	builder:dedent()

	builder:append_indent()
	builder:append("end")

	ctx.current_fn = prev_fn
	ctx.block_queue = prev_queue
	ctx.block_queue_filter = prev_filter
end

function gen_anon_fn(ctx: Context, anon_fn: lir.AnonymousFn)
	local builder = ctx.builder
	builder:append("function")
	gen_fn_body(ctx, anon_fn)
end

function gen_fn(ctx: Context, fn: lir.Fn)
	local builder = ctx.builder
	builder:append_indent()

	local name = fn.name
	if name.type == "projection" then
		builder:append("function ")
		gen_projection(ctx, name :: any)
	elseif name.type == "constant" then
		builder:append("local function ")
		builder:append(name.value)
	else
		strong_exhaustive_match(name.type)
	end

	gen_fn_body(ctx, fn)
	builder:append("\n")
end

local function append_method(ctx: Context, casing: Casing, method: cased_method.Method, anon_fn: lir.AnonymousFn)
	local builder = ctx.builder
	builder:append_indent()
	builder:append(cased_method(casing, method))
	builder:append(" = ")
	gen_anon_fn(ctx, anon_fn)
	builder:append(",\n")
end

local function append_method_if_exists(
	ctx: Context,
	casing: Casing,
	method: cased_method.Method,
	anon_fn: lir.AnonymousFn?
)
	if anon_fn == nil then
		return
	end

	return append_method(ctx, casing, method, anon_fn)
end

local function casing_from_export(hhir: Hir, export: lir.Export): Casing
	local file_id = id.file(export.decl.id)
	local file_options = hhir.options[file_id]
	if file_options == nil then
		return panic(`Expected file {file_id} to have options`)
	end

	return file_options.casing or options.casing.default
end

local function gen_export(ctx: Context, target: compilation.Target, export: lir.Export)
	local builder = ctx.builder

	local name = export.name
	local is_root = name == ""
	local casing = casing_from_export(ctx.hir, export)

	if is_root then
		builder:append_line("{")
	else
		builder:append_line(`{name} = \{`)
	end

	builder:indent()

	if is_root then
		if target == "client" then
			append_method(ctx, casing, "step_replication", ctx.lir.client.step_replication)
		elseif target == "server" then
			append_method(ctx, casing, "step_replication", ctx.lir.server.step_replication)
		end

		builder:append_line("exports = {")
		builder:indent()
	end

	if export.kind == "type" then
		append_method(ctx, casing, "read", export.read)
		append_method(ctx, casing, "write", export.write)
		append_method(ctx, casing, "write_to", export.write_to)
	elseif export.kind == "event" then
		if target == "server" then
			local methods = export.server
			append_method_if_exists(ctx, casing, "fire", methods.fire_client)
			append_method_if_exists(ctx, casing, "fire_all", methods.fire_all)
			append_method_if_exists(ctx, casing, "fire_list", methods.fire_list)
			append_method_if_exists(ctx, casing, "fire_except", methods.fire_except)
			append_method_if_exists(ctx, casing, "on", methods.on)
			append_method_if_exists(ctx, casing, "iter", methods.iter)
		elseif target == "client" then
			local methods = export.client
			append_method_if_exists(ctx, casing, "fire", methods.fire_server)
			append_method_if_exists(ctx, casing, "on", methods.on)
			append_method_if_exists(ctx, casing, "iter", methods.iter)
		end
	elseif export.kind == "function" then
		if target == "server" then
			append_method(ctx, casing, "on", export.on)
		elseif target == "client" then
			append_method(ctx, casing, "invoke", export.invoke_server)
		end
	elseif export.kind == "scope" then
		for _, item in export.items do
			if (item.kind == "event" or item.kind == "function") and target == "types" then
				continue
			end

			gen_export(ctx, target, item)
			builder:append(",\n")
		end
	end

	if is_root then
		builder:dedent()
		builder:append_line("}")
	end

	builder:dedent()
	builder:append_indent()
	builder:append("}")
end

local function populate_type_names(ctx: Context)
	local hhir = ctx.hir
	local type_names = ctx.type_names

	local function next_scope(scope: hir.Scope, prefix: string)
		if scope.scope ~= nil then
			prefix = `{prefix}{scope.name}_`
		end

		for _, decl in scope.values do
			if decl.kind == "scope" then
				next_scope(decl, prefix)
			elseif decl.kind == "type" then
				local name = `{prefix}{decl.name}`
				type_names[decl.id] = name
			end
		end
	end

	next_scope(hhir.entry_scope, "")
end

export type Props = {
	lir: lir.Lir,
	hir: hir.Hir,
	hash: string,
	profile: compilation.Profile,
	entry_options: options.FileOptions,
}

local function from_lir(props: Props, target: compilation.Target): string
	local hhir = props.hir
	local llir = props.lir
	local entry_options = props.entry_options
	local builder = string_builder.create({})

	local ctx: Context = {
		lir = llir,
		hir = hhir,
		builder = builder,

		current_fn = nil,
		current_block = nil,
		if_chains = {},
		block_queue = {},
		block_queue_filter = {},
		seen_registers = {},

		type_names = {},
	}

	append_headers(builder)

	populate_type_names(ctx)
	for decl_id, ttype in hhir.types do
		local type_name = assert_panic(ctx.type_names[decl_id], "expected type to have a cached type name") :: string

		builder:append("export type ")
		builder:append(type_name)

		if ttype.generics then
			builder:append("<")
			for index, generic in ttype.generics do
				if index > 1 then
					builder:append(", ")
				end

				append_luau_type(ctx, generic)
			end
			builder:append(">")
		end

		builder:append(" = ")

		local type_ty = hir.ty_from_id(hhir, ttype.ty_id)
		append_luau_type(ctx, type_ty)

		builder:append("\n")
	end

	builder:append_line("")

	if target ~= "types" then
		local hash = props.hash
		local reliable_name = md5(`{hash}+reliable`)
		local unreliable_name = md5(`{hash}+unreliable`)

		if target == "client" then
			append_client(builder, reliable_name, unreliable_name)
		elseif target == "server" then
			append_server(builder, reliable_name, unreliable_name)
		end
	end

	append_buffer_fns(builder)

	for name, value in llir.globals do
		builder:append("local ")
		builder:append(name)
		builder:append(" = ")
		gen_rvalue(ctx, value)
		builder:append("\n")
	end

	for _, fn in llir.fn_map do
		gen_fn(ctx, fn)
	end

	if target ~= "types" then
		local target_fns = target == "client" and llir.client or llir.server
		local signal_name = target == "client" and "OnClientEvent" or "OnServerEvent"

		local event_map: { [keyof<typeof(target_fns)>]: string } =
			{ reliable_receive = RELIABLE_EVENT, unreliable_receive = UNRELIABLE_EVENT }

		for key, event_global in event_map do
			builder:append(event_global)
			builder:append(".")
			builder:append(signal_name)
			builder:append(":Connect(")
			gen_anon_fn(ctx, target_fns[key])
			builder:append(")\n")
		end

		if entry_options.manual_replication ~= true then
			gen_global(ctx, globals.services.run_service)
			builder:append(".Heartbeat:Connect(")
			gen_anon_fn(ctx, target_fns.step_replication)
			builder:append(")\n")
		end
	end

	builder:append_line("")
	builder:append("return ")
	gen_export(ctx, target, llir.export)

	return string_builder.finalize(builder)
end

return table.freeze({
	from_lir = from_lir,
})
