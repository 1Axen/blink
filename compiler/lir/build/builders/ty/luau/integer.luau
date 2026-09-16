local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local condition = require("@builders/condition")
local constant = require("@builders/constant")
local control = require("@builders/control")
local fn = require("@builders/fn")
local library = require("@builders/library")

local context = require("@lir/build/context")

local builder_types = require("../builder_types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type Boolean = ty.Boolean
type Readable<T> = types.Readable<T>
type Writeable<T> = types.Writeable<T>
type Register<T> = types.RegisterId<T>

const INTEGER_SIZE = constant.from_value(8)
const INTEGER_TYPE = constant.from_value("integer")

local function validate(block: Builder, _, value: Readable<integer>)
	local typeof_value = library.typeof(value :: any)
	local is_not_expected_typeof = condition.not_equals(typeof_value :: any, INTEGER_TYPE)

	block:if_single(is_not_expected_typeof, function(block)
		local message = library.string.format("Expected an integer, got %s instead", typeof_value :: any)
		block:call(library.error_rvalue(message) :: any)
	end)
end

local function build_read(props: ReadProps, block: Builder, _, into: Writeable<any>?): Register<integer>
	local advance = control.advance(INTEGER_SIZE)
	return block:store(library.buffer.integer.read(advance) :: any, into :: any)
end

local function build_write(props: WriteProps, block: Builder, tty: ty.Integer, value: Readable<integer>): ()
	if props.validate then
		validate(block, tty, value)
	end

	local allocate = block:allocate(INTEGER_SIZE)
	block:call(library.buffer.integer.write(allocate, value))
end

return table.freeze({
	read = build_read,
	write = build_write,
})
