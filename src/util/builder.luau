--!strict

-- Copyright (c) 2024 Axen

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local BASE_ALLOCATION = 64

local string_builder = {}

function string_builder.create(allocate: number?)
    local stack = table.create(allocate or BASE_ALLOCATION)
    return {
        get = function(): {string}
            return stack
        end,

        append = function(string: string)
            table.insert(stack, string)
        end,

        append_line = function(string: string)
            table.insert(stack, string)
            table.insert(stack, "\n")
        end,

        append_lines = function(lines: {string})
            table.move(lines, 1, #lines, #stack + 1, stack)
        end,

        finish = function()
            return table.concat(stack)
        end
    }
end

return string_builder