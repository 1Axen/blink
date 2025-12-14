local compiler = require("@compiler")
local datatypes = require("./datatypes")
local fs = require("@util/fs")
local luau = require("@lute/luau")
local path = require("@util/path")
local string_builder = require("@util/string_builder")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

type Datatype = datatypes.Datatype
type TypeAPI = {
	write: (any) -> (buffer, number),
	read: (buffer, number?) -> (any, number),
}

local TEMP_PATH = path.from_string("./temp")

local function equals_deep(a: { [any]: any }, b: { [any]: any }): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		if typeof(a) == "buffer" and typeof(b) == "buffer" then
			return buffer.tostring(a) == buffer.tostring(b)
		end

		return a == b
	end

	for key, value in a do
		if not equals_deep(value, b[key]) then
			return false
		end
	end

	for key, value in b do
		if not equals_deep(value, a[key]) then
			return false
		end
	end

	return true
end

local function compile_datatypes(file: string, types: { [string]: Datatype }): { [string]: TypeAPI }
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
	local luau_file_path = path.append_file_name(TEMP_PATH, file, "luau")
	local blink_file_path = path.append_file_name(TEMP_PATH, file, "blink")
	assert(fs.write_string_to_file(luau_file_path, luau_contents).ok, "luau file write failed")
	assert(fs.write_string_to_file(blink_file_path, contents).ok, "blink file write failed")

	local bytecode = luau.compile(luau_contents)
	local chunkname = path.to_string(luau_file_path)
	return luau.load(bytecode, chunkname)()
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

		if name == "buffer" then
			continue
		end

		for value_name, value_datatype in datatypes.primitives do
			datatypes_to_test[`map_{name}_to_{value_name}`] = datatypes.structures.map(datatype, value_datatype)
		end
	end

	local flat_struct = datatypes.structures.struct(fields)
	local nested_fields = table.clone(fields)
	table.insert(nested_fields, flat_struct)

	datatypes_to_test.flat_struct = flat_struct
	datatypes_to_test.nested_struct = datatypes.structures.struct(nested_fields)

	local values: { [string]: any } = {}
	local buffers: { [string]: buffer } = {}
	local compiled_types = compile_datatypes("datatypes", datatypes_to_test)

	test("writing", function()
		for key, datatype in datatypes_to_test do
			local value = datatype.generate()
			local type_api = assert(compiled_types[key])
			values[key] = value
			buffers[key] = type_api.write(value)
		end
	end)

	test("reading", function()
		for key, value in values do
			local buff = buffers[key]
			local type_api = assert(compiled_types[key])
			local read_value = type_api.read(buff)

			if typeof(value) == "table" or typeof(value) == "buffer" then
				expect(read_value).is_deep(value)
			else
				expect(read_value).is(value)
			end
		end
	end)
end
