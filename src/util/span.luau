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

export type Span = {
    text: (code: string) -> string,
    start: number,
    finish: number,
}

local span = {}

function span.create(code: string, start: number, finish: number): Span
    return ({
        text = string.sub(code, start, finish),
        start = start,
        finish = finish,
    })
end

--> Returns a span such that it occupies the space from a to b
function span.union(code: string, a: Span, b: Span): Span
    return span.create(
        code,
        math.min(a.start, b.start), 
        math.max(a.finish, b.finish)
    )
end

--> Returns a span such that it occupies the space between a and b
function span.negate(code: string, a: Span, b: Span): Span
    return span.create(
        code, 
        math.min(a.finish, b.finish) + 1, 
        math.max(a.start, b.start) - 1
    )
end

return span