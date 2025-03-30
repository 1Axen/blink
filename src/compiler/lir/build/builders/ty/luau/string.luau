local ty = require("@structures/ty")
local lir = require("@structures/lir")

local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local control = require("@builders/control")
local library = require("@builders/library")

local context = require("@lir/build/context")
local length = require("./length")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type String = ty.String
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, ty: String): Register<string>
    local len = length.read(props, block, ty)
    local cursor = control.advance(len)
    return block:store(library.buffer.string.read(cursor, len))
end

local function build_write(props: WriteProps, block: Builder, ty: String, value: RValue<string>): ()
    local len = length.write(props, block, ty, unary.len(value :: any))
    local cursor = block:store(control.allocate(len))
    block:call_lib(library.buffer.string.write(cursor, len, value))
end

return table.freeze({
    read = build_read,
    write = build_write,
})