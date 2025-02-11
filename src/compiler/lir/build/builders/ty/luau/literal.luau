local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue = lir.LValue
type RValue = lir.RValue
type Literal = ty.Literal
type Register = lir.RegisterId

local function build_read(ctx: Context, block: Builder, ty: Literal, attributes: Attributes): Register
    local constant = constant.from_ty(ty) :: any
    return block:store(constant :: lir.RValue)
end

local function build_write(ctx: Context, block: Builder, ty: Literal, attributes: Attributes, at: LValue): ()

end

local function validate(ctx: Context, block: Builder, ty: Literal, at: LValue)
    local constant = constant.from_ty(ty)
    local equals = condition.not_equals(at, constant :: any)

    block:if_branch(equals, function(block)
        block:call_lib(library.error(`Expected "{ty.value}"`))
    end)
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate,
        write = validate
    })
})