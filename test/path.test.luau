local tesk_kit = require("@vendor/test_kit")
local TEST, CASE, SKIP, FOCUS, expect = tesk_kit.test()

local ALIAS_PATH = "@alias/../file.luau"
local RELATIVE_PATH = "./.././../././././abc.txt"
local DIRECTORY_PATH = "./directory"
local UNIX_ABSOLUTE_PATH = "/home/john/photos/Cat.png"
local WINDOWS_ABSOLUTE_PATH = "E:\\Documents\\Newsletters\\Summer2018.pdf"

TEST("path.luau", function()
    local path = require("@util/path")

    local alias: path.Path;
    local relative: path.Path;
    local directory: path.Path;
    local unix_absolute: path.Path;
    local windows_absolute: path.Path;

    CASE("Constructors", function()
        alias = path.from_string(ALIAS_PATH)
        relative = path.from_string(RELATIVE_PATH)
        directory = path.from_string(DIRECTORY_PATH)
        unix_absolute = path.from_string(UNIX_ABSOLUTE_PATH)
        windows_absolute = path.from_string(WINDOWS_ABSOLUTE_PATH)
    end)

    CASE("Identifiers", function()
        expect(path.is_relative_path(alias)).to_be(true)
        expect(path.is_relative_path(relative)).to_be(true)
        expect(path.is_relative_path(directory)).to_be(true)
        expect(path.is_absolute_path(unix_absolute)).to_be(true)
        expect(path.is_absolute_path(windows_absolute)).to_be(true)
    end)

    CASE("Name, stem and extension are parsed", function()
        -- relative
        expect(path.file_name(relative)).to_be("abc.txt")
        expect(path.file_stem(relative)).to_be("abc")
        expect(path.file_extension(relative)).to_be("txt")
    
        -- unix absolute
        expect(path.file_name(unix_absolute)).to_be("Cat.png")
        expect(path.file_stem(unix_absolute)).to_be("Cat")
        expect(path.file_extension(unix_absolute)).to_be("png")

        -- unix absolute
        expect(path.file_name(windows_absolute)).to_be("Summer2018.pdf")
        expect(path.file_stem(windows_absolute)).to_be("Summer2018")
        expect(path.file_extension(windows_absolute)).to_be("pdf")
    end)

    CASE("Absolute conversion", function()
        local absolute = path.to_absolute_path(relative)
        expect(path.is_absolute_path(absolute)).to_be(true)
        expect(path.to_string(absolute)).to_contain_substring(path.to_string(relative))
    end)

    CASE("String conversion", function()
        expect(path.to_string(relative)).to_be(RELATIVE_PATH)
        expect(path.to_string(unix_absolute)).to_be(UNIX_ABSOLUTE_PATH)

        local replaced_path = string.gsub(path.to_string(windows_absolute), "/", "\\")
        expect(replaced_path).to_be(WINDOWS_ABSOLUTE_PATH)
    end)

    CASE("Joining", function()
        local LEFT_STRING = "./foo"
        local RIGHT_STRING = "../bar/foo_bar"
        
        local left_path = path.from_string(LEFT_STRING)
        local right_path = path.from_string(RIGHT_STRING)
        local joint_path = path.join(left_path, right_path)

        expect(path.to_string(joint_path)).to_be(`{LEFT_STRING}/{RIGHT_STRING}`)
    end)

    CASE("Parent traversal", function()
        local photos = path.parent(unix_absolute)
        expect(photos).to_be_truthy()
        assert(photos)

        local john = path.parent(photos)
        expect(john).to_be_truthy()
        assert(john)

        local home = path.parent(john)
        expect(home).to_be_truthy()
        assert(home)
        
        local root = path.parent(home)
        expect(root).to_be_truthy()
        assert(root)

        expect(path.parent(root)).to_be_nil()
       
        expect(path.to_string(photos)).to_be("/home/john/photos")
        expect(path.to_string(john)).to_be("/home/john")
        expect(path.to_string(home)).to_be("/home")
        expect(path.to_string(root)).to_be("")
    end)

    CASE("File name strip", function()
        SKIP()

        local photos = path.strip_file_name(unix_absolute)
        expect(path.to_string(photos)).to_be("/home/john/photos")
        expect(path.to_string(path.strip_file_name(directory))).to_be(DIRECTORY_PATH)
    end)

    CASE("File name setter", function()
        local dog_jpeg = path.with_file_name(unix_absolute, "Dog", "jpeg")
        expect(path.to_string(dog_jpeg)).to_be("/home/john/photos/Dog.jpeg")
    end)

    CASE("Starts with", function()
        expect(path.starts_with(alias, "@")).to_be(true)
        expect(path.starts_with(alias, "@alias")).to_be(true)
        expect(path.starts_with(unix_absolute, "")).to_be(true)
        expect(path.starts_with(windows_absolute, "E:")).to_be(true)
    end)
end)

return nil