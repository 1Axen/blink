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

	const function write_expect_fails<T>(type: TypeAPI, value: T)
		expect(function()
			type.write(value)
		end).fails()
	end

	const function write_read_expect_is<T>(type: TypeAPI, value: T)
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
			write_read_expect_is(exports.all_enums, ENUMS.Axis.X)
			write_read_expect_is(exports.all_enums, ENUMS.AlphaMode.Opaque)
		end)

		test("constrained enum accepts only same enum types", function()
			write_read_expect_is(exports.axis_enum, ENUMS.Axis.X)
			write_expect_fails(exports.axis_enum, ENUMS.AlphaMode.Opaque)
		end)
	end

	do
		--stylua: ignore
		const exports = setup_test("vector", [[
			@export
			type unbounded = vector
			@export
			type exact = vector(1)
			@export
			type bounded = vector(0..1)
			@export
			type lower_bounded = vector(0..)
			@export
			type upper_bounded = vector(..1)
		]])

		const nan_vector = vector.create(math.nan, 0)
		const inf_vector = vector.create(math.huge, 0)

		test("unbounded vector", function()
			write_read_expect_is(exports.unbounded, nan_vector)
			write_read_expect_is(exports.unbounded, inf_vector)
			write_read_expect_is(exports.unbounded, vector.one)
			write_read_expect_is(exports.unbounded, vector.zero)
		end)

		test("exact vector", function()
			write_expect_fails(exports.exact, inf_vector)
			write_expect_fails(exports.exact, nan_vector)
			write_expect_fails(exports.exact, vector.one)
			write_expect_fails(exports.exact, vector.zero)
			write_read_expect_is(exports.exact, vector.create(1, 0, 0))
		end)

		test("bounded vector", function()
			write_expect_fails(exports.bounded, inf_vector)
			write_expect_fails(exports.bounded, nan_vector)
			write_expect_fails(exports.bounded, vector.one)
			write_read_expect_is(exports.bounded, vector.zero)
			write_read_expect_is(exports.bounded, vector.create(1, 0, 0))

			-- lower
			write_expect_fails(exports.lower_bounded, nan_vector)
			write_read_expect_is(exports.lower_bounded, inf_vector)
			write_read_expect_is(exports.lower_bounded, vector.zero)
			write_read_expect_is(exports.lower_bounded, vector.one)
			write_read_expect_is(exports.lower_bounded, vector.one * 2)
			write_read_expect_is(exports.lower_bounded, vector.create(0.5, 0, 0))

			-- upper
			write_expect_fails(exports.upper_bounded, inf_vector)
			write_expect_fails(exports.upper_bounded, nan_vector)
			write_expect_fails(exports.upper_bounded, vector.one * 2)
			write_read_expect_is(exports.upper_bounded, vector.zero)
			write_read_expect_is(exports.upper_bounded, vector.create(0.5, 0, 0))
		end)
	end

	do
		--stylua: ignore
		const exports = setup_test("floats", [[
			@export
			type unbounded = f32
			@export
			type bounded = f32(0..1)
			@export
			type lower_bounded = f32(0..)
			@export
			type upper_bounded = f32(..1)
		]])

		test("unbounded float", function()
			write_read_expect_is(exports.unbounded, math.nan)
			write_read_expect_is(exports.unbounded, 0.5)
			write_read_expect_is(exports.unbounded, math.huge)
		end)

		test("bounded float", function()
			-- upper & lower
			write_expect_fails(exports.bounded, math.nan)
			write_expect_fails(exports.bounded, 2)
			write_expect_fails(exports.bounded, -1)
			write_read_expect_is(exports.bounded, 0)
			write_read_expect_is(exports.bounded, 0.5)
			write_read_expect_is(exports.bounded, 1)

			-- lower
			write_expect_fails(exports.lower_bounded, math.nan)
			write_expect_fails(exports.lower_bounded, -1)
			write_read_expect_is(exports.lower_bounded, 0)
			write_read_expect_is(exports.lower_bounded, 0.5)
			write_read_expect_is(exports.lower_bounded, 1)
			write_read_expect_is(exports.lower_bounded, 2)

			-- upper
			write_expect_fails(exports.upper_bounded, math.nan)
			write_expect_fails(exports.upper_bounded, 2)
			write_read_expect_is(exports.upper_bounded, -1)
			write_read_expect_is(exports.upper_bounded, 0)
			write_read_expect_is(exports.upper_bounded, 0.5)
			write_read_expect_is(exports.upper_bounded, 1)
		end)
	end

	do
		--stylua: ignore
		const exports = setup_test("floats", [[
			@export
			type unbounded = f64
			@export
			type bounded = f64(0..1)
			@export
			type lower_bounded = f64(0..)
			@export
			type upper_bounded = f64(..1)
		]])

		test("unbounded double", function()
			write_read_expect_is(exports.unbounded, math.nan)
			write_read_expect_is(exports.unbounded, math.pi)
			write_read_expect_is(exports.unbounded, math.huge)
		end)

		test("bounded double", function()
			-- upper & lower
			write_expect_fails(exports.bounded, math.nan)
			write_expect_fails(exports.bounded, math.huge)
			write_expect_fails(exports.bounded, -math.huge)
			write_expect_fails(exports.bounded, 2)
			write_expect_fails(exports.bounded, -1)
			write_read_expect_is(exports.bounded, 0)
			write_read_expect_is(exports.bounded, 0.5)
			write_read_expect_is(exports.bounded, 1)

			-- lower
			write_expect_fails(exports.lower_bounded, math.nan)
			write_expect_fails(exports.lower_bounded, -math.huge)
			write_expect_fails(exports.lower_bounded, -1)
			write_read_expect_is(exports.lower_bounded, 0)
			write_read_expect_is(exports.lower_bounded, 0.5)
			write_read_expect_is(exports.lower_bounded, 1)
			write_read_expect_is(exports.lower_bounded, 2)
			write_read_expect_is(exports.lower_bounded, math.huge)

			-- upper
			write_expect_fails(exports.upper_bounded, math.nan)
			write_expect_fails(exports.upper_bounded, math.huge)
			write_expect_fails(exports.upper_bounded, 2)
			write_read_expect_is(exports.upper_bounded, -1)
			write_read_expect_is(exports.upper_bounded, 0)
			write_read_expect_is(exports.upper_bounded, 0.5)
			write_read_expect_is(exports.upper_bounded, 1)
			write_read_expect_is(exports.upper_bounded, -math.huge)
		end)
	end
end
