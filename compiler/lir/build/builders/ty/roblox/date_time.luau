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

type Writeable<T> = types.Writeable<T>
type Readable<T> = types.Readable<T>
type Register<T> = types.RegisterId<T>

local FORMAT = ty_numeral.f64
const TIMESTAMP_FIELD = constant.from_value("UnixTimestamp")

local function build_read(
	props: ReadProps,
	block: Builder,
	date_time: ty.DateTime,
	into: Writeable<any>?
): Register<DateTime>
	local timestamp = ty_numeral.read(props, block, FORMAT)
	return block:store(library.DateTime.from_timestamp(timestamp), into)
end

local function build_write(props: WriteProps, block: Builder, date_time: ty.DateTime, value: Readable<DateTime>): ()
	local timestamp = projection.index(value, TIMESTAMP_FIELD)
	ty_numeral.write(props, block, FORMAT, timestamp)
end

return table.freeze({
	read = build_read,
	write = build_write,
})
