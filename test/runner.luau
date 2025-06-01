local fs = require("@lune/fs")
local process = require("@lune/process")
local test_kit = require("@vendor/test_kit")

fs.writeDir("./temp")

do -- run all tests
	require("@test/id.test")
	require("@test/fs.test")
	require("@test/path.test")
end

fs.removeDir("./temp")

local success = test_kit.finish()
process.exit(success and 0 or 1)
