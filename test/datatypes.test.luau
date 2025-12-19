local brick_color_mock = require("@test/mock/brick_color_mock")
local cframe_mock = require("@test/mock/cframe_mock")
local color3_mock = require("@test/mock/color3_mock")
local compiler = require("@compiler")
local datatypes = require("./datatypes")
local date_time_mock = require("@test/mock/date_time_mock")
local fs = require("@util/fs")
local luau = require("@lute/luau")
local path = require("@util/path")
local string_builder = require("@util/string_builder")
local typeof_mock = require("@test/mock/typeof_mock")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

type Datatype = datatypes.Datatype
type TypeAPI = {
	write: (any) -> (buffer, number),
	read: (buffer, number?) -> (any, number),
}

local TEMP_PATH = path.from_string("./temp")

local ENV = table.freeze({
	type = type,
	print = print,
	error = error,
	assert = assert,
	math = math,
	table = table,
	buffer = buffer,
	vector = vector,

	typeof = typeof_mock,
	Color3 = color3_mock,
	CFrame = cframe_mock,
	DateTime = date_time_mock,
	BrickColor = brick_color_mock,
})

local PRIMITIVES = datatypes.primitives
local UNHASHABLE_DATATYPES: { [Datatype]: true? } = {
	[PRIMITIVES.buffer] = true,
	[PRIMITIVES.CFrame] = true,
	[PRIMITIVES.Color3] = true,
	[PRIMITIVES.DateTime] = true,
	[PRIMITIVES.BrickColor] = true,
	[PRIMITIVES.DateTimeMillis] = true,
}

local function compile_datatypes(file: string, types: { [string]: Datatype }): { [string]: TypeAPI }
	local luau_file_path = path.append_file_name(TEMP_PATH, file, "luau")
	if fs.exists(luau_file_path) then
		local read_result = fs.read_string_from_file(luau_file_path)
		assert(read_result.ok)

		local bytecode = luau.compile(read_result.value)
		local chunkname = path.to_string(luau_file_path)
		return luau.load(bytecode, chunkname, ENV :: any)()
	end

	local builder = string_builder.create({})

	for name, datatype in types do
		builder:append_line("@export")
		builder:append("type ")
		builder:append(name)
		builder:append(" = ")
		datatype.append(builder)
		builder:append("\n")
	end

	local contents = builder:finalize()
	local compiled_targets = compiler.compile_contents(contents, {
		profile = "test",
	})

	local luau_contents = compiled_targets.types
	local blink_file_path = path.append_file_name(TEMP_PATH, file, "blink")
	assert(fs.write_string_to_file(luau_file_path, luau_contents).ok, "luau file write failed")
	assert(fs.write_string_to_file(blink_file_path, contents).ok, "blink file write failed")

	local bytecode = luau.compile(luau_contents)
	local chunkname = path.to_string(luau_file_path)
	return luau.load(bytecode, chunkname, ENV :: any)()
end

return function(tiniest: Tiniest)
	local test = tiniest.test
	local expect = tiniest.expect

	local datatypes_to_test: { [string]: Datatype } = {}

	local fields = {}
	for name, datatype in datatypes.primitives do
		table.insert(fields, datatype)
		datatypes_to_test[`type_{name}`] = datatype
		datatypes_to_test[`array_{name}`] = datatypes.structures.array(datatype)

		local key = datatype
		if UNHASHABLE_DATATYPES[key] then
			key = PRIMITIVES.u8
		end

		datatypes_to_test[`map_{name}_to_{name}`] = datatypes.structures.map(key, datatype)
	end

	local flat_struct = datatypes.structures.struct(fields)
	local nested_fields = table.clone(fields)
	table.insert(nested_fields, flat_struct)

	datatypes_to_test.flat_struct = flat_struct
	datatypes_to_test.nested_struct = datatypes.structures.struct(nested_fields)

	local values: { [string]: any } = {}
	local buffers: { [string]: buffer } = {}
	local compiled_types = compile_datatypes("datatypes", datatypes_to_test)

	for key, datatype in datatypes_to_test do
		test(`write {key}`, function()
			local value = datatype.generate()
			local type_api = assert(compiled_types[key])
			values[key] = value
			buffers[key] = type_api.write(value)
		end)

		test(`read {key}`, function()
			local buff = buffers[key]
			local value = values[key]
			local type_api = assert(compiled_types[key])
			local read_value = type_api.read(buff)

			if typeof(value) == "table" or typeof(value) == "buffer" then
				expect(read_value).is_deep(value)
			else
				expect(read_value).is(value)
			end
		end)
	end
end
