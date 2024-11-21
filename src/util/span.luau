--!strict
--!native

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

local location = require("./location")

type Location = location.Location
export type Span = {
    start: Location,
    finish: Location,
}

local function create(start: Location, finish: Location): Span
    return table.freeze({
        start = start,
        finish = finish
    }) :: Span
end

--- creates a span from a to b
local function merge(a: Span, b: Span): Span
    return create(a.start, b.finish)
end

local function length(self: Span): number
    return (self.finish.position - self.start.position) + 1
end

local function value(self: Span, text: buffer): string
    return buffer.readstring(text, self.start.position, length(self))
end

local function contains(self: Span, position: number): boolean
    return self.start.position <= position and self.finish.position >= position
end

--- checks if two spans are intersecting, assumes `a.start` <= `b.start`
local function intersects(a: Span, b: Span): boolean
    return (a.finish.position >= b.start.position)
end

local function is_multiline(self: Span): boolean
    local start_line = self.start.line
    local finish_line = self.finish.line
    return start_line ~= finish_line
end

return table.freeze({
    create = create,
    merge = merge,
    length = length,
    contains = contains,
    intersects = intersects,
    is_multiline = is_multiline,
    to_string = value,
})