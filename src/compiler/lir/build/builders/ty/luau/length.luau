local ty = require("@structures/ty")
local lir = require("@structures/lir")

local primitives = require("@config/primitives")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")

local context = require("@lir/build/context")

local panic = require("@util/panic")
local range = require("@util/range")
local conversion = require("@util/conversion")

type Builder = fn.Builder
type Context = context.Context

type String = ty.String
type Buffer = ty.Buffer

type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local function to_range(ty: Buffer | String): range.Range
    if ty.kind == "buffer" then
        return primitives.buffer.range
    elseif ty.kind == "string" then
        return primitives.string.range 
    end

    return panic(`Unhandled ty kind: "{ty.kind}"`)
end

local function is_exact_length(ty: Buffer | String): number?
    local bounds = ty.length
    if bounds == nil then
        return nil
    end

    if bounds.min ~= bounds.max then
        return nil
    end

    return conversion.to_byte_size(bounds.min)
end

local function read_length(ty: Buffer | String): lir.ProjCall
    local bounds = ty.length or to_range(ty)
    local size = conversion.to_byte_size(bounds.max)

    local bytes = constant.from_value(size)
    local advance = control.advance(bytes)

    if size == 1 then
        return library.buffer.u8.read(advance)
    elseif size == 2 then
        return library.buffer.u16.read(advance)
    elseif size == 4 then
        return library.buffer.u32.read(advance)
    end

    return panic(`Unhandled byte size: {size}`)
end

local function write_length(block: Builder, ty: Buffer | String, at: LValue): lir.Constant<number>
    local bounds = ty.length or to_range(ty)
    local size = conversion.to_byte_size(bounds.max)
    
    local length = unary.len(at)
    local bytes = constant.from_value(size)
    local allocate = block:store(control.allocate(bytes))

    if size == 1 then
        library.buffer.u8.write(allocate, length)
    elseif size == 2 then
        library.buffer.u16.write(allocate, length)
    elseif size == 4 then
        library.buffer.u32.write(allocate, length)
    else
        return panic(`Unhandled byte size: {size}`)
    end

    return bytes
end

return table.freeze({
    read = read_length,
    write = write_length,
    is_exact = is_exact_length,
})