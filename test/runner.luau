local process = require('@lune/process')
local test_kit = require("@vendor/test_kit")
local colorful = require("@vendor/colorful")

do -- run all tests
    require("@test/path.test")
end

local success = test_kit.finish()
process.exit(success and 0 or 1)