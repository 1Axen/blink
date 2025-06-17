local lir = require("@lir/types")

local panic = require("@util/panic")
local string_builder = require("@util/string_builder")

local fmt_ty = require("@ty/format")
local fmt_types = require("@util/format_types")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")

local colorful = require("@vendor/colorful")

type StringBuilder = string_builder.StringBuilder

local ID_STYLE = colorful.combineStyles({ colorful.modifier.dim })
local CALL_STYLE = colorful.combineStyles({ colorful.color.red })
local BASE_STYLE = colorful.combineStyles({ colorful.color.red })
local TERM_STYLE = colorful.combineStyles({ colorful.modifier.bold })
local BLOCK_STYLE = colorful.combineStyles({ colorful.color.blue, colorful.modifier.bold })
local INDEX_STYLE = colorful.combineStyles({ colorful.color.blueBright })

local fmt_lvalue: (fmt_builder: StringBuilder, lvalue: lir.LValue<any>) -> ()
local fmt_rvalue: (fmt_builder: StringBuilder, rvalue: lir.RValue<any>) -> ()

local function block_ident(block: lir.BasicBlock): string
	return colorful.color.yellow(`bb{block.index}`)
end

local function separated<T>(
	fmt_builder: StringBuilder,
	formatter: (fmt_builder: StringBuilder, value: T, index: number) -> (),
	list: { T },
	separator: string
)
	local length = #list
	for index, value in list do
		formatter(fmt_builder, value, index)

		if index < length then
			string_builder.append(fmt_builder, separator)
			string_builder.append(fmt_builder, " ")
		end
	end
end

local function fmt_id(fmt_builder: StringBuilder, id: lir.Id<any>)
	if id.kind == "argument" then
		string_builder.append(fmt_builder, ID_STYLE("a"))
	elseif id.kind == "register" then
		string_builder.append(fmt_builder, ID_STYLE("$"))
	else
		strong_exhaustive_match(id.kind)
	end

	string_builder.append(fmt_builder, ID_STYLE(tostring(id.index)))
end

local function fmt_global(fmt_builder: StringBuilder, global: lir.Global<any>)
	string_builder.append(fmt_builder, ID_STYLE(`@{global.identifier}`))
end

local function fmt_return(fmt_builder: StringBuilder, retrn: lir.Return, index: number)
	string_builder.append(fmt_builder, fmt_ty(retrn.ty))
end

local function fmt_argument(fmt_builder: StringBuilder, argument: lir.Argument, index: number)
	local name = `a{index}`
	if argument.name then
		name ..= ` ({argument.name})`
	end

	local formatted_ty = fmt_ty(argument.ty)
	string_builder.append(fmt_builder, `{name}: {formatted_ty}`)
end

local function fmt_constant(fmt_builder: StringBuilder, constant: lir.Constant<any>)
	string_builder.append(fmt_builder, fmt_types.any(constant.value))
end

local function fmt_structure(fmt_builder: StringBuilder, structure: lir.Structure<any>)
	if structure.kind == "array" then
		string_builder.append(fmt_builder, "{")
		separated(fmt_builder, fmt_rvalue, structure.values, ",")
		string_builder.append(fmt_builder, "}")
	elseif structure.kind == "map" then
		string_builder.append(fmt_builder, "{")
		for index, value in structure.values do
			fmt_rvalue(fmt_builder, index)
			string_builder.append(fmt_builder, " = ")
			fmt_rvalue(fmt_builder, value)
			string_builder.append(fmt_builder, ",")
		end
		string_builder.append(fmt_builder, "}")
	elseif structure.kind == "struct" then
		string_builder.append(fmt_builder, "(")
		for key, value in structure.values do
			string_builder.append(fmt_builder, key.value)
			string_builder.append(fmt_builder, " = ")
			fmt_rvalue(fmt_builder, value)
			string_builder.append(fmt_builder, ",")
		end
		string_builder.append(fmt_builder, ")")
	end
end

local function fmt_projection(fmt_builder: StringBuilder, projection: lir.Projection<any>)
	local base = projection.base
	if base.type == "constant" then
		string_builder.append(fmt_builder, BASE_STYLE(tostring(base.value)))
	else
		fmt_lvalue(fmt_builder, projection.base :: lir.LValue<any>)
	end

	if projection.kind == "call" or projection.kind == "namecall" then
		if projection.kind == "namecall" then
			string_builder.append(fmt_builder, ":")
			string_builder.append(fmt_builder, CALL_STYLE(projection.method.value))
		end

		string_builder.append(fmt_builder, "(")
		separated(fmt_builder, fmt_rvalue, projection.args, ",")
		string_builder.append(fmt_builder, ")")
	elseif projection.kind == "index" then
		string_builder.append(fmt_builder, ".")
		string_builder.append(fmt_builder, INDEX_STYLE(tostring(projection.element.value)))
	elseif projection.kind == "field" then
		string_builder.append(fmt_builder, "[")
		fmt_rvalue(fmt_builder, projection.field)
		string_builder.append(fmt_builder, "]")
	else
		strong_exhaustive_match(projection.kind)
	end
end

local function fmt_condition(fmt_builder: StringBuilder, condition: lir.Condition<any>)
	local symbol = ""
	if condition.kind == "equals" then
		symbol = "=="
	elseif condition.kind == "not_equals" then
		symbol = "!="
	elseif condition.kind == "less_than" then
		symbol = "<"
	elseif condition.kind == "less_than_or" then
		symbol = "<="
	elseif condition.kind == "greater_than" then
		symbol = ">"
	elseif condition.kind == "greater_than_or" then
		symbol = ">="
	end

	string_builder.append(fmt_builder, "(")

	if condition.left then
		fmt_rvalue(fmt_builder, condition.left)
		string_builder.append(fmt_builder, ` {symbol} `)
	else
		string_builder.append(fmt_builder, symbol)
	end

	if condition.right then
		(fmt_rvalue :: any)(fmt_builder, condition.right)
	end

	string_builder.append(fmt_builder, ")")
end

local function fmt_ternary(fmt_builder: StringBuilder, ternary: lir.Ternary<any>)
	fmt_condition(fmt_builder, ternary.cond)
	string_builder.append(fmt_builder, " ? ")
	fmt_rvalue(fmt_builder, ternary.left)
	string_builder.append(fmt_builder, " : ")
	fmt_rvalue(fmt_builder, ternary.right)
end

local function fmt_control(fmt_builder: StringBuilder, control: lir.Control<any>)
	string_builder.append(fmt_builder, colorful.modifier.dim(control.kind))
	string_builder.append(fmt_builder, "(")
	fmt_rvalue(fmt_builder, control.bytes)
	string_builder.append(fmt_builder, ")")
end

local function fmt_unary(fmt_builder: StringBuilder, unary: lir.UnaryOp<any>)
	local symbol = ""
	if unary.kind == "len" then
		symbol = "#"
	end

	string_builder.append(fmt_builder, symbol)
	fmt_rvalue(fmt_builder, unary.of)
end

local function fmt_binary(fmt_builder: StringBuilder, binary: lir.BinaryOp<any>)
	local symbol = ""
	if binary.kind == "add" then
		symbol = "+"
	elseif binary.kind == "sub" then
		symbol = "-"
	elseif binary.kind == "mul" then
		symbol = "*"
	elseif binary.kind == "div" then
		symbol = "/"
	elseif binary.kind == "mod" then
		symbol = "%"
	elseif binary.kind == "idiv" then
		symbol = "//"
	end

	string_builder.append(fmt_builder, `(`)
	fmt_rvalue(fmt_builder, binary.left)
	string_builder.append(fmt_builder, ` {symbol} `)
	fmt_rvalue(fmt_builder, binary.right)
	string_builder.append(fmt_builder, `)`)
end

function fmt_rvalue(fmt_builder: StringBuilder, rvalue: lir.RValue<any>)
	if rvalue.type == "id" then
		fmt_id(fmt_builder, rvalue)
	elseif rvalue.type == "unary" then
		fmt_unary(fmt_builder, rvalue)
	elseif rvalue.type == "binary" then
		fmt_binary(fmt_builder, rvalue)
	elseif rvalue.type == "global" then
		fmt_global(fmt_builder, rvalue)
	elseif rvalue.type == "control" then
		fmt_control(fmt_builder, rvalue)
	elseif rvalue.type == "structure" then
		fmt_structure(fmt_builder, rvalue)
	elseif rvalue.type == "ternary" then
		fmt_ternary(fmt_builder, rvalue)
	elseif rvalue.type == "constant" then
		fmt_constant(fmt_builder, rvalue :: lir.Constant)
	elseif rvalue.type == "condition" then
		fmt_condition(fmt_builder, rvalue :: any)
	elseif rvalue.type == "projection" then
		fmt_projection(fmt_builder, rvalue)
	else
		strong_exhaustive_match(rvalue.type)
	end
end

function fmt_lvalue(fmt_builder: StringBuilder, lvalue: lir.LValue<any>)
	if lvalue.type == "projection" then
		fmt_projection(fmt_builder, lvalue)
	elseif lvalue.type == "global" then
		fmt_global(fmt_builder, lvalue)
	elseif lvalue.type == "id" then
		fmt_id(fmt_builder, lvalue)
	else
		panic(`Unhandaled lvalue kind "{lvalue.type}"`)
	end
end

local function fmt_loop(fmt_builder: StringBuilder, loop: lir.Loop)
	if loop.kind == "generic" then
		string_builder.append(fmt_builder, "for(")

		if loop.index then
			fmt_id(fmt_builder, loop.index)
		else
			string_builder.append(fmt_builder, "_")
		end

		string_builder.append(fmt_builder, ", ")
		fmt_id(fmt_builder, loop.value)

		string_builder.append(fmt_builder, ", ")

		local target = loop.target
		fmt_rvalue(fmt_builder, target :: any)

		string_builder.append(fmt_builder, ")")
	elseif loop.kind == "numeric" then
		string_builder.append(fmt_builder, "for(")
		fmt_id(fmt_builder, loop.index)
		string_builder.append(fmt_builder, ", ")
		fmt_rvalue(fmt_builder, loop.iterations :: any)
		string_builder.append(fmt_builder, ")")
	end
end

local function fmt_statement(fmt_builder: StringBuilder, statement: lir.Statement)
	if statement.kind == "call" then
		fmt_projection(fmt_builder, statement.call)
	elseif statement.kind == "assign" then
		fmt_lvalue(fmt_builder, statement.into)
		string_builder.append(fmt_builder, " = ")

		if statement.value then
			fmt_rvalue(fmt_builder, statement.value)
		else
			string_builder.append(fmt_builder, "_")
		end
	elseif statement.kind == "remark" then
		string_builder.append(fmt_builder, colorful.modifier.dim(`REMARK {statement.text}`))
	elseif statement.kind == "multi_assign" then
		separated(fmt_builder, fmt_lvalue, statement.into, ",")

		string_builder.append(fmt_builder, " = ")
		fmt_rvalue(fmt_builder, statement.value)
	else
		strong_exhaustive_match(statement.kind)
	end
end

local function fmt_terminator(fmt_builder: StringBuilder, terminator: lir.Terminator)
	if terminator.kind == "if" then
		fmt_condition(fmt_builder, terminator.cond)
		string_builder.append(fmt_builder, " -> ")
		string_builder.append(fmt_builder, `[{block_ident(terminator.truthy)}, {block_ident(terminator.falsey)}]`)
	elseif terminator.kind == "call" then
		string_builder.append(fmt_builder, `${terminator.fn}(`)
		separated(fmt_builder, fmt_rvalue, terminator.args, ",")
		string_builder.append(fmt_builder, `) -> {block_ident(terminator.destination)}`)
	elseif terminator.kind == "loop" then
		fmt_loop(fmt_builder, terminator.loop)
		string_builder.append(fmt_builder, ` -> {block_ident(terminator.destination)}`)
	elseif terminator.kind == "goto" then
		string_builder.append(fmt_builder, `{TERM_STYLE("goto")} -> {block_ident(terminator.destination)}`)
	elseif terminator.kind == "none" then
		string_builder.append(fmt_builder, colorful.modifier.dim("()"))
	elseif terminator.kind == "return" then
		string_builder.append(fmt_builder, `{TERM_STYLE("return")} `)
		separated(fmt_builder, fmt_rvalue, terminator.values, ",")
	else
		strong_exhaustive_match(terminator.kind)
	end
end

local function fmt_block(fmt_builder: StringBuilder, block: lir.BasicBlock)
	local indent = (block.scope + 1)
	for _ = 1, indent do
		string_builder.indent(fmt_builder)
	end

	string_builder.append_line(fmt_builder, `{block_ident(block)}: \{`)
	string_builder.indent(fmt_builder)

	-- statements
	for _, statement in block.statements do
		string_builder.append_indent(fmt_builder)
		fmt_statement(fmt_builder, statement)
		string_builder.append(fmt_builder, ";\n")
	end

	-- terminator
	string_builder.append_indent(fmt_builder)
	fmt_terminator(fmt_builder, block.terminator)
	string_builder.append(fmt_builder, ";\n")

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")

	for _ = 1, indent do
		string_builder.dedent(fmt_builder)
	end
end

local function fmt_fn(fmt_builder: StringBuilder, fn: lir.Fn)
	string_builder.append_indent(fmt_builder)

	string_builder.append(fmt_builder, `fn {BLOCK_STYLE(fn.name)} (`)
	separated(fmt_builder, fmt_argument, fn.args, ",")

	string_builder.append(fmt_builder, ") -> (")
	separated(fmt_builder, fmt_return, fn.rets, ",")
	string_builder.append(fmt_builder, ") {\n")

	string_builder.indent(fmt_builder)

	for _, block in fn.blocks do
		fmt_block(fmt_builder, block)
	end

	string_builder.dedent(fmt_builder)
	string_builder.append_line(fmt_builder, "}")
end

local function fmt_lir(lir: lir.Lir): string
	local fmt_builder = string_builder.create()

	for fn_id, fn in lir.fns do
		fmt_fn(fmt_builder, fn)
		string_builder.append_line(fmt_builder, "")
	end

	return string_builder.to_string(fmt_builder)
end

return fmt_lir
