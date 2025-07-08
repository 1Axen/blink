local attributes = require("@config/attributes")
local lir = require("@lir/types")
local ty = require("@ty/types")

local context = require("@lir/build/context")

local binary = require("@builders/binary")
local condition = require("@builders/condition")
local constant = require("@builders/constant")
local fn = require("@builders/fn")
local globals = require("@builders/globals")
local library = require("@builders/library")
local projection = require("@builders/projection")
local ternary = require("@builders/ternary")

local numeral = require("../luau/numeral")
local types = require("../types")

type TyBuilder = types.TyBuilder
type ReadProps = types.ReadProps
type WriteProps = types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type Unknown = ty.Unknown

type LValue<T> = lir.LValue<T>
type RValue<T> = lir.RValue<T>
type Register<T> = lir.RegisterId<T>

local FORMAT = numeral.u8

local function build_read(props: ReadProps, block: Builder, _: Unknown, into: LValue<any>?)
	local byte_register = numeral.read(props, block, FORMAT)
	local value_register = (into or block:reserve())

	local exists = condition.equals(byte_register, constant.one)
	block:if_branch(exists, function(block)
		local unknown_cursor = globals.incoming.unknown_cursor
		local value = projection.field(globals.incoming.unknown :: LValue<any>, unknown_cursor)
		block:store(binary.add(unknown_cursor, constant.one), unknown_cursor)
		block:store(value, value_register)
	end)

	return value_register
end

local function build_write(props: WriteProps, block: Builder, _: Unknown, value: RValue<any>): ()
	local exists = condition.not_equals(value, constant.null)
	local cursor = block:allocate(constant.one)

	block:if_branch(exists, function(block)
		block:call(library.table.insert(globals.outgoing.unknown, value))
	end)

	local as_number = ternary(exists, constant.one, constant.zero)
	block:call(library.buffer.u8.write(cursor, as_number))
end

return table.freeze({
	read = build_read,
	write = build_write,
})
