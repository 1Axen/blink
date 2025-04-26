local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local structure = require("@builders/structure")
local constant = require("@builders/constant")
local projection = require("@builders/projection")

local context = require("@lir/build/context")
local ty_builder = require("@builders/ty")

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type Struct = ty.Struct
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, struct: Struct, into: LValue<any>?): Register<any>
    local register: Register<any> = block:store(structure.struct({}))
    for _, field in struct.fields do
        local name = field.name
        local value_register = ty_builder.read(props, block, field.value)

        local struct_index = projection.field(register, constant.from_value(name))
        block:store(value_register, struct_index)
    end

    if into then
        return block:store(register, into)
    end

    return register
end

local function build_write(props: WriteProps, block: Builder, struct: Struct, value: RValue<any>): ()
    for _, field in struct.fields do
        local name = field.name
        local struct_index = projection.field(value :: LValue<any>, constant.from_value(name))
        local field_register = block:store(struct_index)
        ty_builder.write(props, block, field.value, field_register)
    end
end

return table.freeze({
    read = build_read,
    write = build_write,
})