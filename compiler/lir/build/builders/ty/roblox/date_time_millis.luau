local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local ty_numeral = require("../luau/numeral")

local constant = require("@builders/constant")
local fn = require("@builders/fn")
local library = require("@builders/library")
local projection = require("@builders/projection")

local context = require("@lir/build/context")

local builder_types = require("../builder_types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type DateTimeMillis = ty.DateTimeMillis
type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

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
	) :: types.ProjIndex<number>
	ty_numeral.write(props, block, FORMAT, timestamp)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
