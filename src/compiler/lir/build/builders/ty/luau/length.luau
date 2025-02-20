local ty = require("@structures/ty")
local lir = require("@structures/lir")

local bounds = require("@config/bounds")
local primitives = require("@config/primitives")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local unary = require("@builders/unary")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")

local numeral = require("./numeral")

local context = require("@lir/build/context")

local panic = require("@util/panic")
local range = require("@util/range")
local conversion = require("@util/conversion")

type Range = range.Range

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

type VariableLengthTy = ty.Buffer | ty.String | ty.Array<ty.Ty> | ty.Map

local function to_range(ty: VariableLengthTy): Range?
    if ty.kind == "buffer" then
        return ty.length
    elseif ty.kind == "string" then
        return ty.length
    elseif ty.kind == "array" then
        return ty.size
    elseif ty.kind == "map" then
        return ty.size
    end

    return panic(`Unhandled ty kind: "{ty.kind}"`)
end

local function to_max_range(ty: VariableLengthTy): Range
    if ty.kind == "buffer" then
        return primitives.buffer.range
    elseif ty.kind == "string" then
        return primitives.string.range
    elseif ty.kind == "array" then
        return bounds.array
    elseif ty.kind == "map" then
        return bounds.map
    end

    return panic(`Unhandled ty kind: "{ty.kind}"`)
end

--- Returns the smallest possible numeral that can encode the ty's bounds/length
local function to_range_numeral(ty: VariableLengthTy): ty.Numeral
    local bounds = to_range(ty) or to_max_range(ty)
    return conversion.to_numeral(bounds.max)
end

local function to_exact_length(ty: VariableLengthTy): number?
    local ty_range = to_range(ty)
    if ty_range == nil then
        return nil
    end

    if ty_range.min ~= ty_range.max then
        return nil
    end

    return ty_range.min
end

local function read_length(ctx: Context, block: Builder, ty: VariableLengthTy, attributes: Attributes): lir.RegisterId | lir.Constant<number>
    local exact_length = to_exact_length(ty)
    if exact_length ~= nil then
        return constant.from_value(exact_length)
    end
    
    local range_numeral = to_range_numeral(ty)
    return numeral.build.read(ctx, block, range_numeral, attributes)
end

local function write_length(ctx: Context, block: Builder, ty: VariableLengthTy, attributes: Attributes, len: RValue): lir.RegisterId | lir.Constant<number>
    local exact_length = to_exact_length(ty)
    if exact_length then
        return constant.from_value(exact_length)
    end

    local len_register = block:store(len)
    local range_numeral = to_range_numeral(ty)
    numeral.build.write(ctx, block, range_numeral, attributes, len_register)

    return len_register
end

return table.freeze({
    read = read_length,
    write = write_length,
    is_exact = to_exact_length,
})