local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local control = require("@builders/control")
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

type Ty = ty.Ty
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function build_read(props: ReadProps, block: Builder, ty: Ty): Register
    return block:store()
end

local function build_write(props: WriteProps, block: Builder, ty: Ty, value: RValue): ()

end

local function validate_read(ctx: Context, block: Builder, ty: Ty, at: LValue)
    
end

local function validate_write(ctx: Context, block: Builder, ty: Ty, at: LValue)
    
end

return table.freeze({
    read = build_read,
    write = build_write,
})