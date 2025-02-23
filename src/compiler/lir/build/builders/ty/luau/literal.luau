local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue = lir.LValue
type RValue = lir.RValue
type Literal = ty.Literal
type Register = lir.RegisterId

local function build_read(props: ReadProps, block: Builder, literal: ty.Literal): Register
    local constant = constant.from_ty(literal)
    return block:store(constant :: lir.RValue)
end

local function build_write(props: WriteProps, block: Builder, literal: ty.Literal, value: RValue): ()

end

local function validate(ctx: Context, block: Builder, ty: Literal, at: LValue)
    local constant = constant.from_ty(ty)
    local equals = condition.not_equals(at, constant :: any)

    block:if_branch(equals, function(block)
        block:call_lib(library.error(`Expected "{ty.value}"`))
    end)
end

return table.freeze({
    read = build_read,
    write = build_write,
})