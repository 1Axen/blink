type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lune").configure({}))

local ALIAS_PATH = "@alias/../file.luau"
local RELATIVE_PATH = "./.././../././././abc.txt"
local DIRECTORY_PATH = "./directory"
local UNIX_ABSOLUTE_PATH = "/home/john/photos/Cat.png"
local WINDOWS_ABSOLUTE_PATH = "E:\\Documents\\Newsletters\\Summer2018.pdf"

return function(tiniest: Tiniest)
	local describe = tiniest.describe
	local test = tiniest.test
	local expect = tiniest.expect

	local path = require("@util/path")

	local alias: path.Path
	local relative: path.Path
	local directory: path.Path
	local unix_absolute: path.Path
	local windows_absolute: path.Path

	describe("constructors", function()
		test("alias", function()
			alias = path.from_string(ALIAS_PATH)
		end)

		test("relative", function()
			relative = path.from_string(RELATIVE_PATH)
			directory = path.from_string(DIRECTORY_PATH)
		end)

		test("absolute", function()
			unix_absolute = path.from_string(UNIX_ABSOLUTE_PATH)
			windows_absolute = path.from_string(WINDOWS_ABSOLUTE_PATH)
		end)
	end)

	describe("identification", function()
		test("relative", function()
			expect(path.is_relative_path(alias)).is_true()
			expect(path.is_relative_path(relative)).is_true()
			expect(path.is_relative_path(directory)).is_true()
		end)

		test("absolute", function()
			expect(path.is_absolute_path(unix_absolute)).is_true()
			expect(path.is_absolute_path(windows_absolute)).is_true()
		end)

		test("starts with", function()
			expect(path.starts_with(alias, "@")).is_true()
			expect(path.starts_with(alias, "@alias")).is_true()
			expect(path.starts_with(unix_absolute, "")).is_true()
			expect(path.starts_with(windows_absolute, "E:")).is_true()
		end)
	end)

	describe("filename parsing", function()
		test("relative", function()
			expect(path.file_name(relative)).is("abc.txt")
			expect(path.file_stem(relative)).is("abc")
			expect(path.file_extension(relative)).is("txt")
		end)

		test("unix absolute", function()
			expect(path.file_name(unix_absolute)).is("Cat.png")
			expect(path.file_stem(unix_absolute)).is("Cat")
			expect(path.file_extension(unix_absolute)).is("png")
		end)

		test("windows absolute", function()
			expect(path.file_name(windows_absolute)).is("Summer2018.pdf")
			expect(path.file_stem(windows_absolute)).is("Summer2018")
			expect(path.file_extension(windows_absolute)).is("pdf")
		end)
	end)

	describe("conversion", function()
		test("to absolute", function()
			local absolute = path.to_absolute_path(relative)
			expect(path.is_absolute_path(absolute)).is_true()

			local start = string.find(path.to_string(absolute), path.to_string(relative), 1, true)
			expect(start).exists()
		end)

		test("to string", function()
			expect(path.to_string(relative)).is(RELATIVE_PATH)
			expect(path.to_string(unix_absolute)).is(UNIX_ABSOLUTE_PATH)

			local replaced_path = string.gsub(path.to_string(windows_absolute), "/", "\\")
			expect(replaced_path).is(WINDOWS_ABSOLUTE_PATH)
		end)
	end)

	describe("modifications", function()
		test("joining", function()
			local LEFT_STRING = "./foo"
			local RIGHT_STRING = "../bar/foo_bar"

			local left_path = path.from_string(LEFT_STRING)
			local right_path = path.from_string(RIGHT_STRING)
			local joint_path = path.join(left_path, right_path)

			expect(path.to_string(joint_path)).is(`{LEFT_STRING}/{RIGHT_STRING}`)
		end)

		test("strip file name", function()
			if true then
				return
			end

			local photos = path.strip_file_name(unix_absolute)
			expect(path.to_string(photos)).is("/home/john/photos")
			expect(path.to_string(path.strip_file_name(directory))).is(DIRECTORY_PATH)
		end)

		test("set file name", function()
			local dog_jpeg = path.with_file_name(unix_absolute, "Dog", "jpeg")
			expect(path.to_string(dog_jpeg)).is("/home/john/photos/Dog.jpeg")
		end)
	end)

	describe("traversal", function()
		test("unix absolute", function()
			local photos = path.parent(unix_absolute)
			expect(photos).exists()
			assert(photos)

			local john = path.parent(photos)
			expect(john).exists()
			assert(john)

			local home = path.parent(john)
			expect(home).exists()
			assert(home)

			local root = path.parent(home)
			expect(root).exists()
			assert(root)

			expect(path.parent(root)).never_exists()

			expect(path.to_string(photos)).is("/home/john/photos")
			expect(path.to_string(john)).is("/home/john")
			expect(path.to_string(home)).is("/home")
			expect(path.to_string(root)).is("")
		end)
	end)
end
