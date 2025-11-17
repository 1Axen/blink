local file = require("@util/file")
local path = require("@util/path")
local runtime_fs = require("@lute/fs")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

local TEMP_PATH = path.from_string("./temp")
local FILE_PATH = path.join(TEMP_PATH, path.from_string(`./file.txt`))
local FILE_MOVE_PATH = path.join(TEMP_PATH, path.from_string("file_move.txt"))
local FILE_COPY_PATH = path.join(TEMP_PATH, path.from_string("file_copy.txt"))
local DIRECTORY_PATH = path.join(TEMP_PATH, path.from_string(`./directory`))
local FILE_CONTENTS = "Hello, World!"

return function(tiniest: Tiniest)
	local describe = tiniest.describe
	local test = tiniest.test
	local expect = tiniest.expect

	local fs = require("@util/fs")

	describe("methods", function()
		test("write", function()
			local file_result = fs.write_string_to_file(FILE_PATH, FILE_CONTENTS)
			local directory_result = fs.write_directory(DIRECTORY_PATH)

			expect(file_result.ok).is_true()
			expect(directory_result.ok).is_true()

			expect(runtime_fs.type(path.to_string(FILE_PATH))).is("file")
			expect(runtime_fs.type(path.to_string(DIRECTORY_PATH))).is("dir")
		end)

		test("read", function()
			local file_result = fs.read_file(FILE_PATH)
			local directory_result = fs.read_directory(DIRECTORY_PATH)
			local file_string_result = fs.read_string_from_file(FILE_PATH)

			expect(file_result.ok).is_true()
			expect(directory_result.ok).is_true()
			expect(file_string_result.ok).is_true()

			local file_object = assert(file_result.ok and file_result.value)
			local directory_entries = assert(directory_result.ok and directory_result.value)
			local file_contents = assert(file_string_result.ok and file_string_result.value)

			expect(file.as_string(file_object)).is(FILE_CONTENTS)
			expect(file_contents).is(FILE_CONTENTS)
			expect(#directory_entries).is(0)
		end)

		test("is", function()
			expect(fs.is_file(FILE_PATH)).is_true()
			expect(fs.is_directory(FILE_PATH)).never_is_true()

			expect(fs.is_file(DIRECTORY_PATH)).never_is_true()
			expect(fs.is_directory(DIRECTORY_PATH)).is_true()
		end)

		test("metadata", function()
			local file_result = fs.metadata(FILE_PATH)
			local directory_result = fs.metadata(DIRECTORY_PATH)

			expect(file_result.ok).is_true()
			expect(directory_result.ok).is_true()

			local file_metadata = assert(file_result.ok and file_result.value)
			local directory_metadata = assert(directory_result.ok and directory_result.value)

			expect(file_metadata.kind).is("file")
			expect(directory_metadata.kind).is("dir")
		end)

		test("exists", function()
			expect(fs.exists(FILE_PATH)).is_true()
			expect(fs.exists(DIRECTORY_PATH)).is_true()
		end)

		test("copy", function()
			expect(fs.copy(FILE_PATH, FILE_COPY_PATH).ok).is_true()
			expect(fs.exists(FILE_PATH)).is_true()
			expect(fs.exists(FILE_COPY_PATH)).is_true()
		end)

		test("move", function()
			expect(fs.move(FILE_PATH, FILE_MOVE_PATH).ok).is_true()
			expect(fs.exists(FILE_PATH)).never_is_true()
			expect(fs.exists(FILE_MOVE_PATH)).is_true()
		end)
	end)
end
