--!strict

local types = require("@lir/types")

local binary = require("./binary")
local constant = require("./constant")
local fn = require("./fn")
local globals = require("./globals")
local library = require("./library")
local projection = require("@builders/projection")
local unary = require("./unary")

type LValue<T> = types.LValue<T>
type RValue<T> = types.RValue<T>
type Register<T> = types.RegisterId<T>

type Call<T> = types.ProjCall<T>
type Index<T> = types.ProjIndex<T>
type Field<T> = types.ProjField<T>
type Namecall<T> = types.ProjNamecall<T>

type Advance = types.CtrlAdvance<number>
type Allocate = types.CtrlAllocate<number>

type Save = { write __phantom_type: "__SYMBOL__save", type: "save" }

local OUTGOING = globals.outgoing

local function reset_outgoing(block: fn.Builder)
	block:store(constant.zero, OUTGOING.cursor)
	block:call(library.table.clear(OUTGOING.unknown))
end

local function create_save()
	return projection.call(constant.from_value("create_save"), {})
end

local function update_save(block: fn.Builder, save: LValue<Save>, buf: RValue<buffer>, len: RValue<number>)
	local out_unknown = OUTGOING.unknown
	local save_buffers = projection.index(save :: any, constant.from_value("buffers"))
	local save_lengths = projection.index(save :: any, constant.from_value("lengths"))
	local save_unknown = block:store(projection.index(save :: any, constant.from_value("unknown")))

	block:call(library.table.insert(save_buffers, buf))
	block:call(library.table.insert(save_lengths, len))
	block:call(
		library.table.move(
			out_unknown,
			constant.one,
			unary.len(out_unknown :: any),
			binary.add(unary.len(save_unknown :: any), constant.one),
			save_unknown
		)
	)
end

return table.freeze({
	create_save = create_save,
	update_save = update_save,
	reset_outgoing = reset_outgoing,
})
