local fs = require("@lute/fs")
local process = require("@lute/process")
local tiniest = require("@vendor/tiniest/tiniest_for_lute").configure({
	snapshot_path = "./test/__snapshots__",
	save_snapshots = true,
})

local function recursive_rmdir(path: string)
	if not fs.exists(path) or fs.type(path) ~= "dir" then
		return
	end

	for _, entry in fs.listdir(path) do
		local filename = `{path}/{entry.name}`
		if entry.type == "dir" then
			recursive_rmdir(filename)
		else
			fs.remove(filename)
		end
	end

	fs.rmdir(path)
end

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

if fs.exists("./temp") then
	recursive_rmdir("./temp")
end

fs.mkdir("./temp")
local result = tiniest.run_tests(tests, {})
recursive_rmdir("./temp")

local success = result.status_tally.fail == 0
process.exit(success and 0 or 1)
