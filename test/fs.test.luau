local file = require("@util/file")
local lune_fs = require("@lune/fs")
local path = require("@util/path")

type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lune").configure({}))

local TEMP_PATH = path.from_string("./temp")
local FILE_PATH = path.join(TEMP_PATH, path.from_string(`./file.txt`))
local DIRECTORY_PATH = path.join(TEMP_PATH, path.from_string(`./directory`))
local FILE_CONTENTS = "Hello, World!"

return function(tiniest: Tiniest)
	local describe = tiniest.describe
	local test = tiniest.test
	local expect = tiniest.expect

	local fs = require("@util/fs")

	describe("methods", function()
		test("write", function()
			local file_result =
				fs.write_file(FILE_PATH, file.from_source(path.file_name(FILE_PATH) :: string, FILE_CONTENTS))
			local directory_result = fs.write_directory(DIRECTORY_PATH)

			expect(file_result.error).never_exists()
			expect(directory_result.error).never_exists()

			expect(lune_fs.isFile(path.to_string(FILE_PATH))).is_true()
			expect(lune_fs.isDir(path.to_string(DIRECTORY_PATH))).is_true(true)
		end)

		test("read", function()
			local file_result = fs.read_file(FILE_PATH)
			local directory_result = fs.read_directory(DIRECTORY_PATH)

			expect(file_result.error).never_exists()
			expect(directory_result.error).never_exists()

			-- LUAU
			assert(file_result.value)
			assert(directory_result.value)

			expect(file.as_string(file_result.value)).is(FILE_CONTENTS)
			expect(#directory_result.value).is(0)
		end)

		test("is", function()
			local file_result = fs.is_file(FILE_PATH)
			local directory_result = fs.is_directory(DIRECTORY_PATH)

			expect(file_result.value).is_true()
			expect(directory_result.value).is_true()
		end)

		test("metadata", function()
			local metadata_result = fs.metadata(FILE_PATH)
			expect(metadata_result.error).never_exists()

			local metadata = metadata_result.value :: fs.Metadata
			expect(metadata.exists).is_true()

			-- LUAU
			assert(metadata.exists)
			expect(metadata.kind).is("file")
		end)
	end)
end
