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

local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.TypeAttributes

type DateTimeMillis = ty.DateTimeMillis
type LValue = lir.LValue
type RValue = lir.RValue
type Register = lir.RegisterId

local FORMAT = ty_numeral.f64

local function build_read(props: ReadProps, block: Builder, date_time: DateTimeMillis): Register
    local timestamp = ty_numeral.read(props, block, FORMAT)
    return block:store(library.DateTime.from_timestamp_millis(timestamp))
end

local function build_write(props: WriteProps, block: Builder, date_time: DateTimeMillis, value: RValue): ()
    local timestamp = projection.index(value :: LValue, constant.from_value("UnixTimestampMillis"))
    ty_numeral.write(props, block, FORMAT, timestamp)
end

return table.freeze({
    read = build_read,
    write = build_write,
})