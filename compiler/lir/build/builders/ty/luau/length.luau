local ty = require("@ty/types")
local lir = require("@lir/types")

local bounds = require("@config/bounds")
local primitives = require("@config/primitives")
local attributes = require("@config/attributes")

local fn = require("@builders/fn")
local binary = require("@builders/binary")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")

local numeral = require("./numeral")

local context = require("@lir/build/context")

local panic = require("@util/panic")
local range = require("@util/range")
local conversion = require("@util/conversion")

local types = require("../types")

type VariableLengthTy = 
    | ty.Map
    | ty.Array 
    | ty.String 
    | ty.Buffer 

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Range = range.Range

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type LValue<T = any> = lir.LValue<T>
type RValue<T = any> = lir.RValue<T>
type Register<T = any> = lir.RegisterId<T>

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

--- Returns the numeral and range offset
local function to_relative_range(ty: VariableLengthTy): (ty.Numeral, lir.Constant<number>)
    local range = to_range(ty) or to_max_range(ty)
    local offset = range.min
    local difference = (range.max - offset)
    return conversion.to_min_numeral(difference), constant.from_value(offset)
end

local function validate_exact(block: Builder, ty: VariableLengthTy, value: RValue<number>)
    local bounds = to_range(ty)
    if bounds == nil then
        return
    end

    local exact_length = to_exact_length(ty) :: number
    local is_exact_length = condition.equals(value, constant.from_value(exact_length))

    block:if_branch(is_exact_length, function(block)
        block:call_lib(library.error(`Expected {ty.kind} length to be {bounds.min}`))
    end)
end

local function validate_range(block: Builder, ty: VariableLengthTy, len_register: LValue<number>)
    local bounds = to_range(ty)
    if bounds == nil then
        return
    end

    local lower = condition.less_than(len_register, constant.from_value(bounds.min))
    local upper = condition.greater_than(len_register, constant.from_value(bounds.max))

    block:if_branch(lower, function(block)
        block:call_lib(library.error(`Expected {ty.kind} length to be greater than or equal to {bounds.min}`))
    end)

    block:if_branch(upper, function(block)
        block:call_lib(library.error(`Expected {ty.kind} length to be less than or equal to {bounds.max}`))
    end)
end

local function read_length(props: ReadProps, block: Builder, ty: VariableLengthTy): lir.RegisterId<number> | lir.Constant<number>
    local exact_length = to_exact_length(ty)
    if exact_length ~= nil then
        return constant.from_value(exact_length)
    end

    local format, offset = to_relative_range(ty)
    local len_register = numeral.read(props, block, format)
    len_register = block:store(binary.add(len_register, offset), len_register)
    validate_range(block, ty, len_register)

    return len_register
end

local function write_length(props: WriteProps, block: Builder, ty: VariableLengthTy, value: RValue<number>): lir.RegisterId<number> | lir.Constant<number>
    local exact_length = to_exact_length(ty)
    if exact_length then
        if props.validate then
            validate_exact(block, ty, value)
        end

        return constant.from_value(exact_length)
    end

    local len_register = block:store(value)
    if props.validate then
        validate_range(block, ty, len_register)
    end

    local format, offset = to_relative_range(ty)
    numeral.write(props, block, format, binary.sub(value, offset))

    return len_register
end

return table.freeze({
    read = read_length,
    write = write_length,
    is_exact = to_exact_length,
})