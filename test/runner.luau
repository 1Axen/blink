local fs = require("@lute/fs")
local process = require("@lute/process")
local tiniest = require("@vendor/tiniest/tiniest_for_lute").configure({
	snapshot_path = "./test/__snapshots__",
	load_snapshots = true,
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

if fs.exists("./temp") then
	recursive_rmdir("./temp")
end

fs.mkdir("./temp")

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
end)

local result = tiniest.run_tests(tests, {})
local success = result.status_tally.fail == 0
if success then
	recursive_rmdir("./temp")
end

process.exit(success and 0 or 1)
