--!strict

local types = require("@lir/types")

local constant = require("@builders/constant")
local globals = require("@builders/globals")
local projection = require("@builders/projection")

type Writeable<T> = types.Writeable<T>
type Readable<T> = types.Readable<T>
type Register<T> = types.RegisterId<T>

type Call<T> = types.ProjCall<T>
type Index<T> = types.ProjIndex<T>
type Field<T> = types.ProjField<T>
type Namecall<T> = types.ProjNamecall<T>

type Advance = types.CtrlAdvance<number>
type Allocate = types.CtrlAllocate<number>

local READ_BUFFER = globals.incoming.buffer
local WRITE_BUFFER = globals.outgoing.buffer

local function index(library: string, method: string): Index<any>
	local library_const = constant.from_value(library)
	local method_const = constant.from_value(method)
	return projection.index(library_const, method_const)
end

local function create(size: Readable<number>): Call<buffer>
	return projection.call(index("buffer", "create"), { size })
end

local function len(of: Readable<buffer>): Call<number>
	return projection.call(index("buffer", "len"), { of })
end

local function copy(
	target: Readable<buffer>,
	target_offset: Readable<number>,
	source: Readable<buffer>,
	source_offset: Readable<number>?,
	count: Readable<number>?
): Call<nil>
	return projection.call(index("buffer", "copy"), { target, target_offset, source, source_offset, count })
end

local function read_string(advance: Advance, bytes: Readable<number>): Call<string>
	return projection.call(index("buffer", "readstring"), { READ_BUFFER, advance, bytes })
end

local function write_string(allocate: Register<number>, bytes: Readable<number>, value: Readable<string>): Call<nil>
	return projection.call(index("buffer", `writestring`), { WRITE_BUFFER, allocate, value, bytes })
end

local function read_number(format: string)
	return function(advance: Advance): Call<number>
		return projection.call(index("buffer", `read{format}`), { READ_BUFFER, advance })
	end
end

local function write_number(format: string)
	return function(allocate: Register<number>, value: Readable<number>): Call<nil>
		return projection.call(index("buffer", `write{format}`), { WRITE_BUFFER, allocate, value })
	end
end

local function read_integer(advance: Advance): Call<integer>
	return projection.call(index("buffer", "readinteger"), { READ_BUFFER, advance })
end

local function write_integer(allocate: Register<number>, value: Readable<integer>): Call<nil>
	return projection.call(index("buffer", "writeinteger"), { WRITE_BUFFER, allocate, value })
end

return table.freeze({
	len = len,
	copy = copy,
	create = create,

	u8 = {
		read = read_number("u8"),
		write = write_number("u8"),
	},
	u16 = {
		read = read_number("u16"),
		write = write_number("u16"),
	},
	u32 = {
		read = read_number("u32"),
		write = write_number("u32"),
	},
	i8 = {
		read = read_number("i8"),
		write = write_number("i8"),
	},
	i16 = {
		read = read_number("i16"),
		write = write_number("i16"),
	},
	i32 = {
		read = read_number("i32"),
		write = write_number("i32"),
	},
	f32 = {
		read = read_number("f32"),
		write = write_number("f32"),
	},
	f64 = {
		read = read_number("f64"),
		write = write_number("f64"),
	},
	string = {
		read = read_string,
		write = write_string,
	},
	integer = {
		read = read_integer,
		write = write_integer,
	},
})
