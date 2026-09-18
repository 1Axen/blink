local compiler = require("@compiler")
local enum_mock = require("@test/mock/enum_mock")
local environment_mock = require("@test/mock/environment_mock")
local fs = require("@util/fs")
local luau = require("@lute/luau")
local path = require("@util/path")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

type TypeAPI = {
	read: (buf: buffer, offset: number?) -> (any, number),
	write: (value: any) -> (buffer, number),
}

type ModuleAPI<K> = {
	exports: {
		[K]: TypeAPI,
	},
}

const ENUMS = enum_mock.ENUMS
const TEMP_PATH = path.from_string("./temp")

type function ParseTypeNames(source: type)
	const str = source:value()
	assert(type(str) == "string", "Expected source type to be a stringleton")

	const names = {}
	for line in string.gmatch(str, "[^\r\n]+") do
		local name = string.match(line, "^%s*type%s+([%a_][%w_]*)")
		if name == nil then
			continue
		end

		table.insert(names, types.singleton(name))
	end

	return types.unionof(unpack(names))
end

const function setup_test<T>(prefix: string, contents: T | "")
	const targets = compiler.compile_contents(contents, { profile = "test" })
	const source = targets.types

	const file_name = `{prefix}-validation`
	const luau_file_path = path.append_file_name(TEMP_PATH, file_name, "luau")
	const blink_file_path = path.append_file_name(TEMP_PATH, file_name, "blink")
	assert(fs.write_string_to_file(luau_file_path, source).ok, "luau file write failed")
	assert(fs.write_string_to_file(blink_file_path, contents).ok, "blink file write failed")

	const environment = environment_mock()
	const bytecode = luau.compile(targets.types)
	const module = luau.load(bytecode, tostring(luau_file_path), environment)() :: ModuleAPI<ParseTypeNames<T>>

	return module.exports, environment
end

return function(tiniest: Tiniest)
	local test = tiniest.test
	local expect = tiniest.expect

	const function write_read_checked<T>(type: TypeAPI, value: T)
		local serialized: buffer
		expect(function()
			serialized = type.write(value)
		end).never_fails()

		local deserialized: any
		expect(function()
			deserialized = type.read(serialized)
		end).never_fails()

		expect(deserialized).is(value)
	end

	do
		--stylua: ignore
		const exports = setup_test("enum", [[
			@export
			type all_enums = Enum
			@export
			type axis_enum = Enum<"Axis">
		]])

		test("unconstrained enum accepts all enum types", function()
			write_read_checked(exports.all_enums, ENUMS.Axis.X)
			write_read_checked(exports.all_enums, ENUMS.AlphaMode.Opaque)
		end)

		test("constrained enum accepts only same enum types", function()
			write_read_checked(exports.axis_enum, ENUMS.Axis.X)
			expect(function()
				exports.axis_enum.write(ENUMS.AlphaMode.Opaque)
			end).fails()
		end)
	end
end
