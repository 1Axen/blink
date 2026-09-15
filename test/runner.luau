local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@lute/process")
local tiniest = require("@vendor/tiniest/tiniest_for_lute").configure({
	snapshot_path = "./test/__snapshots__",
	load_snapshots = true,
})

const require: any = require
const temp_path = path.parse("./temp")

if fs.exists(temp_path) then
	print("removed stale temp directory")
	fs.removeDirectory(temp_path, { recursive = true })
end

fs.createDirectory(temp_path)

local tests = tiniest.collect_tests(function()
	local describe = tiniest.describe
	local function describe_from_file(name: string)
		describe(name, function()
			require(`./{name}.test`)(tiniest)
		end)
	end

	describe_from_file("path")
	describe_from_file("fs")
	describe_from_file("id")
	describe_from_file("datatypes")
	describe_from_file("events")
	describe_from_file("functions")
	describe_from_file("diagnostics")

	describe("issues", function()
		require("./issues/92.test")(tiniest)
		require("./issues/94.test")(tiniest)
		require("./issues/90.test")(tiniest)
	end)
end)

local result = tiniest.run_tests(tests, {})
local success = result.status_tally.fail == 0
if success then
	fs.removeDirectory(temp_path, { recursive = true })
end

process.exit(success and 0 or 1)
