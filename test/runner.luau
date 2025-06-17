local fs = require("@lune/fs")
local process = require("@lune/process")
local tiniest = require("@vendor/tiniest/tiniest_for_lune").configure({
	snapshot_path = "./test/__snapshots__",
	save_snapshots = true,
})

local require: any = require

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
end)

fs.writeDir("./temp")
local result = tiniest.run_tests(tests, {})
fs.removeDir("./temp")

local success = result.status_tally.fail == 0
process.exit(success and 0 or 1)
