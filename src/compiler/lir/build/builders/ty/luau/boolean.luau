local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local ternary = require("@builders/ternary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue = lir.LValue
type RValue = lir.RValue
type Boolean = ty.Boolean
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, ty: Boolean, attributes: Attributes): Register
    local bytes = constant.from_value(1)
    local advance = control.advance(bytes)
    local buffer_read = library.buffer.u8.read(advance)

    local truthful = condition.equals(buffer_read, constant.from_value(1))
    local conversion = ternary(truthful, constant.from_value(true), constant.from_value(false)) 

    return block:store(conversion)
end

local function build_write(ctx: Context, block: Builder, ty: Boolean, attributes: Attributes, at: LValue): ()
    local bytes = constant.from_value(1)
    local allocate = block:store(control.allocate(bytes))

    local truthful = condition.equals(at, constant.from_value(true))
    local conversion = ternary(truthful, constant.from_value(1), constant.from_value(0)) 
    local buffer_write = library.buffer.u8.write(allocate, conversion)

    block:call_lib(buffer_write)
end


local function validate_read(ctx: Context, block: Builder, ty: Boolean, at: LValue)

end

local function validate_write(ctx: Context, block: Builder, ty: Boolean, at: LValue)
    local type = constant.from_value("boolean")
    local equals = condition.not_equals(at, type)

    block:if_branch(equals, function(block)
        block:call_lib(library.error(`Expected a boolean`))
    end)
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate_read,
        write = validate_write
    })
})