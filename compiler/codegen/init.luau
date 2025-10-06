--!strict
--!native
--!optimize 2

local append_buffer_fns = require("@codegen/templates/append_buffer_fns")
local append_client = require("@codegen/templates/append_client")
local append_headers = require("@self/templates/append_headers")
local append_server = require("@codegen/templates/append_server")
local compilation = require("@config/compilation")
local context = require("@self/context")
local globals = require("@lir/build/builders/globals")
local hir = require("@hir/types")
local lir = require("@compiler/lir/types")
local md5 = require("@vendor/md5")
local panic = require("@util/panic")
local string_builder = require("@util/string_builder")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local weak_exhaustive_match = require("@util/weak_exhaustive_match")

type Context = context.Context

local gen_lvalue: <T>(ctx: Context, lvalue: lir.LValue<T>) -> ()
local gen_rvalue: <T>(ctx: Context, rvalue: lir.RValue<T>) -> ()
local gen_block: (ctx: Context, block: lir.BasicBlock) -> ()

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
				builder:append(",")
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
				builder:append(",")
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
	elseif id.kind == "argument" then
		local fn = ctx.current_fn
		if fn == nil then
			return panic(`expected a current fn`)
		end

		local index = id.index
		local argument = fn.args[index]
		if argument.name then
			builder:append(argument.name)
		else
			builder:append(`a{index}`)
		end
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
	if condition.kind == "equals" then
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
		builder:append("{")
		for key, value in structure.values do
			builder:append("[")
			gen_rvalue(ctx, key)
			builder:append("] = ")
			gen_rvalue(ctx, value)
			builder:append(",")
		end
		builder:append("}")
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

function gen_rvalue<T>(ctx: Context, rvalue: lir.RValue<T>)
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
		gen_rvalue(ctx, loop.iterations)
	elseif loop.kind == "generic" then
		context.try_see_register(ctx, loop.index)
		gen_id(ctx, loop.index)
		builder:append(", ")
		context.try_see_register(ctx, loop.index)
		gen_id(ctx, loop.value)
		builder:append(" in ")
		gen_rvalue(ctx, loop.target)
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
		gen_block(ctx, terminator.truthy)
	elseif terminator.kind == "call" then
		builder:append_indent()
		local fn = lir.fn_from_id(lirr, terminator.fn)
		for index, ret in terminator.rets do
			if index == 1 and context.try_see_register(ctx, ret) then
				builder:append("local ")
			elseif index > 1 then
				builder:append(",")
			end

			gen_lvalue(ctx, ret)
		end

		if #terminator.rets > 0 then
			builder:append(" = ")
		end

		if fn.name.type == "projection" then
			gen_projection(ctx, fn.name)
		elseif fn.name.type == "constant" then
			builder:append(fn.name.value)
		else
			strong_exhaustive_match(fn.name.type)
		end

		builder:append("(")

		for index, argument in terminator.args do
			if index > 1 then
				builder:append(",")
			end

			gen_rvalue(ctx, argument)
		end

		builder:append(")\n")
		gen_block(ctx, terminator.destination)
	elseif terminator.kind == "goto" then
		builder:dedent()
		builder:append_line("end")
		gen_block(ctx, terminator.destination)
	elseif terminator.kind == "none" then
	elseif terminator.kind == "loop" then
		builder:append_indent()
		gen_loop(ctx, terminator.loop)
		builder:indent()
		gen_block(ctx, terminator.destination)
	elseif terminator.kind == "return" then
		builder:append_indent()
		builder:append("return ")
		for index, value in terminator.values do
			if index > 1 then
				builder:append(",")
			end
			gen_rvalue(ctx, value)
		end
		builder:append("\n")
	else
		weak_exhaustive_match(terminator.kind)
	end
end

local function gen_statement(ctx: Context, statement: lir.Statement)
	local builder = ctx.builder

	if statement.kind == "call" then
		builder:append_indent()
		gen_rvalue(ctx, statement.call)
		builder:append("\n")
	elseif statement.kind == "assign" then
		builder:append_indent()

		local into = statement.into
		if context.try_see_register(ctx, into) then
			builder:append("local ")
		end

		gen_lvalue(ctx, into)

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
				builder:append(",")
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

function gen_block(ctx: Context, block: lir.BasicBlock)
	local builder = ctx.builder

	builder:append_line("-- block start")
	for _, statement in block.statements do
		gen_statement(ctx, statement)
	end
	builder:append_line("-- block end")

	gen_terminator(ctx, block.terminator)
end

local function gen_fn_body(ctx: Context, fn: lir.Fn)
	local builder = ctx.builder

	ctx.current_fn = fn
	table.clear(ctx.seen_registers)

	builder:append("(")

	for index, argument in fn.args do
		if index > 1 then
			builder:append(",")
		end

		builder:append(argument.name or `a{index}`)
	end

	builder:append(")\n")

	builder:indent()
	gen_block(ctx, fn.blocks[1])
	builder:dedent()

	builder:append_line("end")
	ctx.current_fn = nil
end

local function gen_fn(ctx: Context, fn: lir.Fn)
	local builder = ctx.builder
	builder:append_indent()

	if fn.name.type == "projection" then
		builder:append("function ")
		gen_projection(ctx, fn.name)
	elseif fn.name.type == "constant" then
		builder:append("local function ")
		builder:append(fn.name.value)
	else
		strong_exhaustive_match(fn.name.type)
	end

	gen_fn_body(ctx, fn)
end

local function gen_fn_anonymous(ctx: Context, fn: lir.Fn)
	local builder = ctx.builder
	builder:append_indent()

	if fn.name.type == "constant" then
		builder:append(fn.name.value)
	elseif fn.name.type == "projection" then
		gen_projection(ctx, fn.name)
	else
		strong_exhaustive_match(fn.name.type)
	end

	builder:append(" = function")
	gen_fn_body(ctx, fn)
end

export type Props = {
	lir: lir.Lir,
	hir: hir.Hir,
	hash: string,
	profile: compilation.Profile,
}

local function from_lir(props: Props, target: compilation.Target): string
	local lirr = props.lir
	local hirr = props.hir
	local builder = string_builder.create({})

	local ctx: Context = {
		lir = lirr,
		hir = hirr,
		target = target,
		builder = builder,
		scope_paths = {},
		seen_registers = {},
	}

	append_headers(builder)
	append_buffer_fns(builder)

	builder:append("local ")
	gen_global(ctx, globals.types_map)
	builder:append(" = {}\n")

	for name, rvalue in lirr.globals do
		builder:append("local ")
		builder:append(name)
		builder:append(" = ")
		gen_rvalue(ctx, rvalue)
		builder:append("\n")
	end

	for _, fn_set in lirr.tys do
		gen_fn(ctx, lir.fn_from_id(lirr, fn_set.read))
		gen_fn(ctx, lir.fn_from_id(lirr, fn_set.write))
	end

	if target ~= "shared" then
		local hash = props.hash
		local reliable_name = md5(`{hash}+reliable`)
		local unreliable_name = md5(`{hash}+unreliable`)

		if target == "client" then
			append_client(builder, reliable_name, unreliable_name)
		elseif target == "server" then
			append_server(builder, reliable_name, unreliable_name)
		end
	end

	builder:append_line("return {")
	builder:indent()

	if target ~= "shared" then
		for _, event in lirr.events do
			local decl = event.decl
			builder:append_indent()
			builder:append(decl.name)
			builder:append(" = {\n")
			builder:indent()

			local fns = event.fns
			local fn_ids = if target == "server"
				then {
					fns.fire_all,
					fns.fire_list,
					fns.fire_except,
					fns.fire_server,
					fns.iter_server,
					fns.listen_server,
				}
				else {
					fns.fire_client,
					fns.iter_client,
					fns.listen_client,
				}

			for _, fn_id in fn_ids do
				gen_fn_anonymous(ctx, lir.fn_from_id(lirr, fn_id))
				builder:append(",")
			end

			builder:dedent()
			builder:append_line("},")
		end
	end

	builder:dedent()
	builder:append_line("}")

	return string_builder.finalize(builder)
end

return table.freeze({
	from_lir = from_lir,
})
