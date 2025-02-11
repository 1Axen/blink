local ty = require("@structures/ty")
local lir = require("@structures/lir")
local attributes = require("@config/attributes")

local ty_numeral = require("../luau/numeral")

local fn = require("@builders/fn")
local control = require("@builders/control")
local library = require("@builders/library")
local constant = require("@builders/constant")
local condition = require("@builders/condition")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type DateTime = ty.DateTime
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local FORMAT = ty_numeral.f64

local function build_read(ctx: Context, block: Builder, date_time: DateTime, attributes: Attributes): Register
    local timestamp = ty_numeral.build.read(ctx, block, FORMAT, attributes)
    return block:store(library.DateTime.from_timestamp(timestamp))
end

local function build_write(ctx: Context, block: Builder, date_time: DateTime, attributes: Attributes, at: LValue): ()
    local timestamp = projection.index(at, constant.from_value("UnixTimestamp"))
    ty_numeral.build.write(ctx, block, FORMAT, attributes, timestamp)
end

local function validate(ctx: Context, block: Builder, date_time: DateTime, at: LValue)
    
end

return table.freeze({
    build = table.freeze({
        read = build_read,
        write = build_write,
    }),
    validate = table.freeze({
        read = validate,
        write = validate
    })
})