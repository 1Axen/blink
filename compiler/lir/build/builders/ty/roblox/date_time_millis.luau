local attributes = require("@config/attributes")
local lir = require("@lir/types")
local ty = require("@ty/types")

local ty_numeral = require("../luau/numeral")

local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")
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
type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local FORMAT = ty_numeral.f64

local function build_read(
	props: ReadProps,
	block: Builder,
	date_time: DateTimeMillis,
	into: LValue<any>?
): Register<DateTime>
	local timestamp = ty_numeral.read(props, block, FORMAT)
	return block:store(library.DateTime.from_timestamp_millis(timestamp), into)
end

local function build_write(props: WriteProps, block: Builder, date_time: DateTimeMillis, value: RValue<DateTime>): ()
	local timestamp = (
		projection.index(value :: any, constant.from_value("UnixTimestampMillis")) :: any
	) :: lir.ProjIndex<number>
	ty_numeral.write(props, block, FORMAT, timestamp)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
