--!strict

local ty = require("@ty/types")
local lir = require("@lir/types")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")

local context = require("@lir/build/context")

local types = require("@builders/ty/types")

type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Ty = ty.Ty
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function validate_read(props: ReadProps, block: Builder, ty: Ty, value: LValue<any>)
    
end

local function validate_write(props: WriteProps, block: Builder, ty: Ty, value: RValue<any>)
    
end

local function build_read(props: ReadProps, block: Builder, ty: Ty): Register<any>
    local register = block:reserve()
    validate_read(props, block, ty, register)
    return register
end

local function build_write(props: WriteProps, block: Builder, ty: Ty, value: RValue<any>): ()
    validate_write(props, block, ty, value)
end

return table.freeze({
    read = build_read,
    write = build_write,
})