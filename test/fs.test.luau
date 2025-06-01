local lune_fs = require("@lune/fs")

local file = require("@util/file")
local path = require("@util/path")
local tesk_kit = require("@vendor/test_kit")

local TEST, CASE, _, _, expect = tesk_kit.test()

local TEMP = path.from_string("./temp")
local FILE = path.join(TEMP, path.from_string(`./file.txt`))
local DIRECTORY = path.join(TEMP, path.from_string(`./directory`))

local FILE_CONTENTS = "Hello, World!"

TEST("fs.luau", function()
	local fs = require("@util/fs")

	CASE("write", function()
		local file_result = fs.write_file(FILE, file.from_source(path.file_name(FILE) :: string, FILE_CONTENTS))
		local directory_result = fs.write_directory(DIRECTORY)

		expect(file_result.error).to_be_nil()
		expect(directory_result.error).to_be_nil()

		expect(lune_fs.isFile(path.to_string(FILE))).to_be(true)
		expect(lune_fs.isDir(path.to_string(DIRECTORY))).to_be(true)
	end)

	CASE("read", function()
		local file_result = fs.read_file(FILE)
		local directory_result = fs.read_directory(DIRECTORY)

		expect(file_result.error).to_be_nil()
		expect(directory_result.error).to_be_nil()

		-- LUAU
		assert(file_result.value)
		assert(directory_result.value)

		expect(file.as_string(file_result.value)).to_be(FILE_CONTENTS)
		expect(#directory_result.value).to_be(0)
	end)

	CASE("is", function()
		local file_result = fs.is_file(FILE)
		local directory_result = fs.is_directory(DIRECTORY)

		expect(file_result.value).to_be(true)
		expect(directory_result.value).to_be(true)
	end)

	CASE("metadata", function()
		local metadata_result = fs.metadata(FILE)
		expect(metadata_result.error).to_be_nil()

		local metadata = metadata_result.value :: fs.Metadata
		expect(metadata.exists).to_be(true)

		-- LUAU
		assert(metadata.exists)
		expect(metadata.kind).to_be("file")
	end)
end)

return nil
