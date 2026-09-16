local attributes = require("@config/attributes")
local ty = require("@ty")
local types = require("@lir/types")

local fn = require("@builders/fn")

local context = require("@lir/build/context")

local builder_types = require("../builder_types")

type TyBuilder = builder_types.TyBuilder
type ReadProps = builder_types.ReadProps
type WriteProps = builder_types.WriteProps

type Builder = fn.Builder
type Context = context.Context
type Attributes = attributes.Attributes

type Nil = ty.Nil
type Readable<T> = types.Readable<T>
type Writeable<T> = types.Writeable<T>
type Register<T> = types.RegisterId<T>

local function build_read(props: ReadProps, block: Builder, _: Nil, into: Writeable<nil>?): Register<nil>
	-- noop
	return into :: Register<nil> or block:reserve()
end

local function build_write(props: WriteProps, block: Builder, nnil: Nil, value: Readable<nil>): ()
	-- noop
end

return table.freeze({
	read = build_read,
	write = build_write,
})
