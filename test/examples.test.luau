local compiler = require("@compiler")
local fs = require("@std/fs")
local path = require("@util/path")
type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

const EXAMPLES_PATH = path.from_string("./examples")

return function(tiniest: Tiniest)
	const test = tiniest.test
	const expect = tiniest.expect

	for _, entry in fs.listDirectory(tostring(EXAMPLES_PATH)) do
		if entry.type ~= "file" then
			continue
		end

		const file_name = entry.name
		const file_path = path.join(EXAMPLES_PATH, path.from_string(file_name))
		if path.file_extension(file_path) ~= "blink" then
			continue
		end

		test(file_name, function()
			expect(function()
				const result = compiler.compile_from_path(file_path, { profile = "test" })
				if result.ok == false then
					error(result.error)
				end
			end).never_fails()
		end)
	end
end
