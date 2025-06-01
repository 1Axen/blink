local lir = require("@lir/types")

local panic = require("@util/panic")
local builder = require("@util/builder")

local fmt_ty = require("@ty/format")
local fmt_types = require("@util/format_types")

local colorful = require("@vendor/colorful")

type Builder = builder.Builder

local ID_STYLE = colorful.combineStyles({colorful.modifier.dim})
local CALL_STYLE = colorful.combineStyles({colorful.color.red})
local BASE_STYLE = colorful.combineStyles({colorful.color.red})
local TERM_STYLE = colorful.combineStyles({colorful.modifier.bold})
local BLOCK_STYLE = colorful.combineStyles({colorful.color.blue, colorful.modifier.bold})
local INDEX_STYLE = colorful.combineStyles({colorful.color.blueBright})

local fmt_lvalue: (fmt_builder: Builder, lvalue: lir.LValue<any>) -> ()
local fmt_rvalue: (fmt_builder: Builder, rvalue: lir.RValue<any>) -> ()

local function block_ident(block: lir.BasicBlock): string
    return colorful.color.yellow(`bb{block.index}`)
end

local function separated<T>(fmt_builder: Builder, formatter: (fmt_builder: Builder, value: T, index: number) -> (), list: {T}, separator: string)
    local length = #list
    for index, value in list do
        formatter(fmt_builder, value, index)

        if index < length then
            builder.append(fmt_builder, separator)
            builder.append(fmt_builder, " ")
        end
    end
end

local function fmt_id(fmt_builder: Builder, id: lir.Id<any>)
    if id.kind == "argument" then
        builder.append(fmt_builder, ID_STYLE("a"))
    elseif id.kind == "register" then
        builder.append(fmt_builder, ID_STYLE("$"))
    else
        panic(`Unhandled id kind "{id.kind}"`)
    end

    builder.append(fmt_builder, ID_STYLE(tostring(id.index)))
end

local function fmt_global(fmt_builder: Builder, global: lir.Global<any>)
    builder.append(fmt_builder, ID_STYLE(`@{global.identifier}`))
end

local function fmt_return(fmt_builder: Builder, retrn: lir.Return, index: number)
    builder.append(fmt_builder, fmt_ty(retrn.ty))
end

local function fmt_argument(fmt_builder: Builder, argument: lir.Argument, index: number)
    local name = `a{index}`
    if argument.name then
        name ..= ` ({argument.name})`
    end

    local formatted_ty = fmt_ty(argument.ty)
    builder.append(fmt_builder, `{name}: {formatted_ty}`)
end

local function fmt_constant(fmt_builder: Builder, constant: lir.Constant<any>)
    builder.append(fmt_builder, fmt_types.any(constant.value))
end

local function fmt_structure(fmt_builder: Builder, structure: lir.Structure<any>)
    if structure.kind == "array" then
        builder.append(fmt_builder, "{")
        separated(fmt_builder, fmt_rvalue, structure.values, ",")
        builder.append(fmt_builder, "}")
    elseif structure.kind == "map" then
        builder.append(fmt_builder, "{")
        for index, value in structure.values do
            fmt_rvalue(fmt_builder, index)
            builder.append(fmt_builder, " = ")
            fmt_rvalue(fmt_builder, value)
            builder.append(fmt_builder, ",")
        end
        builder.append(fmt_builder, "}")
    elseif structure.kind == "struct" then
        builder.append(fmt_builder, "(")
        for key, value in structure.values do
            builder.append(fmt_builder, key.value)
            builder.append(fmt_builder, " = ")
            fmt_rvalue(fmt_builder, value)
            builder.append(fmt_builder, ",")
        end
        builder.append(fmt_builder, ")")
    end
end

local function fmt_projection(fmt_builder: Builder, projection: lir.Projection<any>)
    local base = projection.base
    if base.type == "constant" then
        builder.append(fmt_builder, BASE_STYLE(tostring(base.value)))
    else
        fmt_lvalue(fmt_builder, projection.base :: lir.LValue<any>)
    end

    if projection.kind == "call" or projection.kind == "namecall" then
        if projection.kind == "namecall" then
            builder.append(fmt_builder, ":")
            builder.append(fmt_builder, CALL_STYLE(projection.method.value))
        end

        builder.append(fmt_builder, "(")
        separated(fmt_builder, fmt_rvalue, projection.args, ",")
        builder.append(fmt_builder, ")")

        return
    elseif projection.kind == "index" then
        builder.append(fmt_builder, ".")
        builder.append(fmt_builder, INDEX_STYLE(tostring(projection.element.value)))
        return
    elseif projection.kind == "field" then
        builder.append(fmt_builder, "[")
        fmt_rvalue(fmt_builder, projection.field)
        builder.append(fmt_builder, "]")
        return
    end

    panic(`Unhandled projection kind "{projection.kind}"`)
end

local function fmt_condition(fmt_builder: Builder, condition: lir.Condition<any>)
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

    builder.append(fmt_builder, "(")

    if condition.left then
        fmt_rvalue(fmt_builder, condition.left)
        builder.append(fmt_builder, ` {symbol} `)
    else
        builder.append(fmt_builder, symbol)
    end

    if condition.right then
        (fmt_rvalue :: any)(fmt_builder, condition.right)
    end

    builder.append(fmt_builder, ")")
end

local function fmt_ternary(fmt_builder: Builder, ternary: lir.Ternary<any>)
    fmt_condition(fmt_builder, ternary.cond)
    builder.append(fmt_builder, " ? ")
    fmt_rvalue(fmt_builder, ternary.left)
    builder.append(fmt_builder, " : ")
    fmt_rvalue(fmt_builder, ternary.right)
end

local function fmt_control(fmt_builder: Builder, control: lir.Control<any>)
    builder.append(fmt_builder, colorful.modifier.dim(control.kind))
    builder.append(fmt_builder, "(")
    fmt_rvalue(fmt_builder, control.bytes)
    builder.append(fmt_builder, ")")
end

local function fmt_unary(fmt_builder: Builder, unary: lir.UnaryOp<any>)
    local symbol = ""
    if unary.kind == "len" then
        symbol = "#"
    end

    builder.append(fmt_builder, symbol)
    fmt_rvalue(fmt_builder, unary.of)
end

local function fmt_binary(fmt_builder: Builder, binary: lir.BinaryOp<any>)
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

    builder.append(fmt_builder, `(`)
    fmt_rvalue(fmt_builder, binary.left)
    builder.append(fmt_builder, ` {symbol} `)
    fmt_rvalue(fmt_builder, binary.right)
    builder.append(fmt_builder, `)`)
end

function fmt_rvalue(fmt_builder: Builder, rvalue: lir.RValue<any>)
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
        panic(`Unhandled rvalue kind "{rvalue.type}"`)
    end
end

function fmt_lvalue(fmt_builder: Builder, lvalue: lir.LValue<any>)
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

local function fmt_loop(fmt_builder: Builder, loop: lir.Loop)
    if loop.kind == "generic" then
        builder.append(fmt_builder, "for(")

        if loop.index then
            fmt_id(fmt_builder, loop.index)
        else
            builder.append(fmt_builder, "_")
        end

        builder.append(fmt_builder, ", ")
        fmt_id(fmt_builder, loop.value)

        builder.append(fmt_builder, ", ")

        local target = loop.target
        if 
            target.type == "projection"
            and (
                target.kind == "field" 
                or target.kind == "index"
            )
        then
            fmt_projection(fmt_builder, target :: any)
        elseif 
            target.type == "id"
            and (
                target.kind == "register" 
                or target.kind == "argument"
            )
        then
            fmt_id(fmt_builder, target :: any)
        else
            panic(`Unhandled loop target type "{target.type}"`)
        end

        builder.append(fmt_builder, ")")
        return
    elseif loop.kind == "numeric" then
        builder.append(fmt_builder, "for(")
        fmt_id(fmt_builder, loop.index :: any)
        builder.append(fmt_builder, ", ")
        fmt_rvalue(fmt_builder, loop.iterations :: any)
        builder.append(fmt_builder, ")")
    end
end

local function fmt_statement(fmt_builder: Builder, statement: lir.Statement)
    if statement.kind == "call" then
        fmt_projection(fmt_builder, statement.call)
        return
    elseif statement.kind == "assign" then
        fmt_lvalue(fmt_builder, statement.into)
        builder.append(fmt_builder, " = ")
        
        if statement.value then
            fmt_rvalue(fmt_builder, statement.value)
        else
            builder.append(fmt_builder, "_")
        end

        return
    elseif statement.kind == "remark" then
        builder.append(fmt_builder, colorful.modifier.dim(`REMARK {statement.text}`))
        return
    elseif statement.kind == "multi_assign" then
        separated(fmt_builder, fmt_lvalue, statement.into, ",")

        builder.append(fmt_builder, " = ")
        fmt_rvalue(fmt_builder, statement.value)

        return
    end

    panic(`Unhandled statement kind "{statement.kind}"`)
end

local function fmt_terminator(fmt_builder: Builder, terminator: lir.Terminator)
    if terminator.kind == "if" then
        fmt_condition(fmt_builder, terminator.cond)
        builder.append(fmt_builder, " -> ")
        builder.append(fmt_builder, `[{block_ident(terminator.truthy)}, {block_ident(terminator.falsey)}]`)
    elseif terminator.kind == "call" then
        builder.append(fmt_builder, `${terminator.fn}(`)
        separated(fmt_builder, fmt_rvalue, terminator.args, ",")
        builder.append(fmt_builder, `) -> {block_ident(terminator.destination)}`)
    elseif terminator.kind == "loop" then
        fmt_loop(fmt_builder, terminator.loop)
        builder.append(fmt_builder, ` -> {block_ident(terminator.destination)}`)
    elseif terminator.kind == "goto" then
        builder.append(fmt_builder, `{TERM_STYLE("goto")} -> {block_ident(terminator.destination)}`)
    elseif terminator.kind == "none" then
        builder.append(fmt_builder, colorful.modifier.dim("()"))
    elseif terminator.kind == "return" then
        builder.append(fmt_builder, `{TERM_STYLE("return")} `)
        separated(fmt_builder, fmt_rvalue, terminator.values, ",")
    else
        panic(`Unhandled terminator kind "{terminator.kind}"`)
    end
end

local function fmt_block(fmt_builder: Builder, block: lir.BasicBlock)
    local indent = (block.scope + 1)
    for _ = 1, indent do
        builder.indent(fmt_builder)
    end

    builder.append_line(fmt_builder, `{block_ident(block)}: \{`)
    builder.indent(fmt_builder)

    -- statements
    for _, statement in block.statements do
        builder.append_indent(fmt_builder)
        fmt_statement(fmt_builder, statement)
        builder.append(fmt_builder, ";\n")
    end

    -- terminator
    builder.append_indent(fmt_builder)
    fmt_terminator(fmt_builder, block.terminator)
    builder.append(fmt_builder, ";\n")

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")

    for _ = 1, indent do
        builder.dedent(fmt_builder)
    end
end

local function fmt_fn(fmt_builder: Builder, fn: lir.Fn)
    builder.append_indent(fmt_builder)

    builder.append(fmt_builder, `fn {BLOCK_STYLE(fn.name)} (`)
    separated(fmt_builder, fmt_argument, fn.args, ",")

    builder.append(fmt_builder, ") -> (")
    separated(fmt_builder, fmt_return, fn.rets, ",")
    builder.append(fmt_builder, ") {\n")

    builder.indent(fmt_builder)

    for _, block in fn.blocks do
        fmt_block(fmt_builder, block)
    end

    builder.dedent(fmt_builder)
    builder.append_line(fmt_builder, "}")
end

local function fmt_lir(lir: lir.Lir): string
    local fmt_builder = builder.create()

    for fn_id, fn in lir.fns do
        fmt_fn(fmt_builder, fn)
        builder.append_line(fmt_builder, "")
    end

    return builder.to_string(fmt_builder)
end

return fmt_lir