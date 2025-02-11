local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local binary = require("@builders/binary")
local library = require("@builders/library")
local control = require("@builders/control")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local context = require("@lir/build/context")

local panic = require("@util/panic")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue = lir.LValue
type RValue = lir.RValue

type Call = lir.ProjCall
type Register = lir.RegisterId
type Advance = lir.CtrlAdvance
type Allocate = lir.CtrlAllocate

type ReadCtor = (cursor: Advance) -> Call
type WriteCtor = (cursor: Register, value: RValue) -> Call

--[[type function concat_literal_union(left: any, right: any)
    local left_components: {singleton} = left:components()
    local right_components: {singleton} = right:components()

    local combined_components = {}
    for _, left_singleton in left_components do
        for _, right_singleton in right_components do
            local combined_singleton = types.singleton(left_singleton:value() .. right_singleton:value())
            table.insert(combined_components, combined_singleton)
        end
    end

    return types.unionof(table.unpack(combined_components))
end]]

local function size_to_byte_size(size: ty.NumSize): number
    if size == "8" then
        return 1
    elseif size == "16" then
        return 2
    elseif size == "32" then
        return 4
    elseif size == "64" then
        return 8
    end

    return panic(`Unhandled numeral size: "{size}"`)
end

local function methods_from_numeral(ty: ty.Numeral): {read: ReadCtor, write: WriteCtor}
    local index = (ty.format .. ty.size)
    local methods = (library.buffer :: any)[index]
    if methods == nil then
        return panic(`No buffer ctor methods exist for numeral kind: "{index}"`)
    end

    return methods
end

local function read_u24(block: Builder): Register
    local lower = control.advance(constant.from_value(2))
    local upper = control.advance(constant.from_value(1))

    return block:store(library.bit32.bor(
        library.buffer.u16.read(lower),
        library.bit32.lshift(
            library.buffer.u8.read(upper), 
            constant.from_value(16)
        )
    ))
end

local function read_i24(block: Builder): Register
    local register = read_u24(block)

    -- handle sign
    block:if_branch(condition.greater_than_or(
        register, 
        constant.from_value(2^23)
    ), function(block)
        block:store(
            binary.sub(
                register, 
                constant.from_value(2^24)
            ),
            register
        )
    end)

    return register
end

local function write_24(block: Builder, at: LValue)
    local lower_cursor = block:store(control.allocate(constant.from_value(2)))
    local upper_cursor = block:store(control.allocate(constant.from_value(1)))
    local shifted_upper = library.bit32.lshift(at, constant.from_value(16))

    block:call_lib(library.buffer.u16.write(lower_cursor, at))
    block:call_lib(library.buffer.u8.write(upper_cursor, shifted_upper))
end

local function read_u48(block: Builder): Register
    local lower = library.buffer.u32.read(control.advance(constant.from_value(4)))
    local upper = library.buffer.u16.read(control.advance(constant.from_value(2)))
    local shifted_lower = binary.mul(constant.from_value(2^16), lower)
    return block:store(binary.add(shifted_lower, upper))
end

local function write_u48(block: Builder, at: LValue)
    local lower_cursor = block:store(control.allocate(constant.from_value(4)))
    local upper_cursor = block:store(control.allocate(constant.from_value(2)))

    local shifted_lower = binary.div(at, constant.from_value(2^16))
    local shifted_upper = binary.mod(at, constant.from_value(2^16))

    block:call_lib(library.buffer.u32.write(lower_cursor, shifted_lower))
    block:call_lib(library.buffer.u16.write(upper_cursor, shifted_upper))
end

local function read_i48(block: Builder): Register
    local register = read_u48(block)

    -- handle sign
    block:if_branch(condition.greater_than_or(
        register, 
        constant.from_value(2^47)
    ), function(block)
        block:store(
            binary.sub(
                register, 
                constant.from_value(2^48)
            ),
            register
        )
    end)

    return register
end

local function write_i48(block: Builder, at: LValue)
    -- handle sign
    block:if_branch(condition.less_than(
        at, 
        constant.from_value(0)
    ), function(block)
        block:store(binary.add(at, constant.from_value(2^48)), at)
    end)

    write_u48(block, at)
end

local function read_f16(block: Builder): Register
    return block:store()
end

local function write_f16(block: Builder, at: LValue)
    
end

local function build_read(ctx: Context, block: Builder, ty: ty.Numeral, attributes: Attributes): Register
    --local format: concat_literal_union<ty.NumFormat, ty.NumSize> = (ty.format .. ty.size) :: any
    local format = (ty.format .. ty.size)

    if format == "u24" then
        return read_u24(block)
    elseif format == "i24" then
        return read_i24(block)
    elseif format == "u48" then
        return read_u48(block)
    elseif format == "i48" then
        return read_i48(block)
    elseif format == "f16" then
        return read_f16(block)
    end

    local size = size_to_byte_size(ty.size)
    local bytes = constant.from_value(size)
    
    local cursor = control.advance(bytes)
    local methods = methods_from_numeral(ty)

    return block:store(methods.read(cursor))
end

local function build_write(ctx: Context, block: Builder, ty: ty.Numeral, attributes: Attributes, at: LValue)
    --local format: concat_literal_union<ty.NumFormat, ty.NumSize> = (ty.format .. ty.size) :: any
    local format = (ty.format .. ty.size)

    if format == "u24" or format == "i24" then
        return write_24(block, at)
    elseif format == "u48" then
        return write_u48(block, at)
    elseif format == "i48" then
        return write_i48(block, at)
    elseif format == "f16" then
        return write_f16(block, at)
    end

    local size = size_to_byte_size(ty.size)
    local bytes = constant.from_value(size)
    local methods = methods_from_numeral(ty)

    local cursor = block:store(control.allocate(bytes))
    block:call_lib(methods.write(cursor, at))
end

local function validate(ctx: Context, block: Builder, ty: ty.Numeral, attributes: Attributes, at: LValue)
    local bounds = ty.bounds
    if bounds == nil then
        return
    end

    local lower = condition.less_than(at, constant.from_value(bounds.min))
    local upper = condition.greater_than(at, constant.from_value(bounds.max))
    
    block:if_branch(lower, function(block)
        block:call_lib(library.error(`Expected number to be greater than or equal to {bounds.min}`))
    end)

    block:if_branch(upper, function(block)
        block:call_lib(library.error(`Expected number to be less than or equal to {bounds.max}`))
    end)
end

return table.freeze({
    build = {
        read = build_read,
        write = build_write
    },
    validate = {
        read = validate,
        write = validate
    },

    u8 = ty.numeral("8", "u"),
    u16 = ty.numeral("16", "u"),
    u24 = ty.numeral("24", "u"),
    u32 = ty.numeral("32", "u"),
    u48 = ty.numeral("48", "u"),

    i8 = ty.numeral("8", "i"),
    i16 = ty.numeral("16", "i"),
    i24 = ty.numeral("24", "i"),
    i32 = ty.numeral("32", "i"),
    i48 = ty.numeral("48", "i"),

    f16 = ty.numeral("16", "f"),
    f32 = ty.numeral("32", "f"),
    f64 = ty.numeral("64", "f"),
})