local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")

local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Instance = ty.Instance

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, instance: Instance, into: LValue<any>?): Register<unknown>
    return block:reserve()
end

local function build_write(props: WriteProps, block: Builder, instance: Instance, value: RValue<unknown>): ()
    
end

return table.freeze({
    read = build_read,
    write = build_write,
})