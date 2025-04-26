local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local globals = require("@builders/globals")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")

local length = require("./length")
local context = require("@lir/build/context")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Buffer = ty.Buffer
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, buf: ty.Buffer): Register<buffer>
    local len = length.read(props, block, buf)
    local register = block:store(library.buffer.create(len))
    local buffer_copy = library.buffer.copy(
        register, constant.zero, 
        globals.incoming.buffer, control.advance(len), len
    )

    block:call_lib(buffer_copy)
    return register
end

local function build_write(props: WriteProps, block: Builder, buf: ty.Buffer, value: RValue<buffer>): ()
    local len = length.write(props, block, buf, library.buffer.len(value))
    local cursor = block:store(control.allocate(len))
    local buffer_copy = library.buffer.copy(
        globals.outgoing.buffer, cursor, 
        value, constant.zero, len
    )

    block:call_lib(buffer_copy)
end

return table.freeze({
    read = build_read,
    write = build_write,
})