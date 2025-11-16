--!strict
local runtime = require("./runtime")

-- Copyright (c) 2024 ffrostfall

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

local RUNTIME = runtime()
local RICHTEXT_TAGS = {
	--> colors
	[30] = `color="#000000"`,
	[31] = `color="#FF6666"`,
	[32] = `color="#66FF66"`,
	[33] = `color="#FFFF66"`,
	[34] = `color="#6666FF"`,
	[35] = `color="#FF66FF"`,
	[36] = `color="#66FFFF"`,
	[37] = `color="#FFFFFF"`,
	[90] = `color="#8c8c8c"`,
	[91] = `color="#FF0000"`,
	[92] = `color="#00FF00"`,
	[93] = `color="#FFFF00"`,
	[94] = `color="#0000FF"`,
	[95] = `color="#FF00FF"`,
	[96] = `color="#00FFFF"`,
	[97] = `color="#FFFFFF"`,

	--> modifiers
	[2] = `transparency="0.5"`,
}

export type Styler = (text: string) -> string

local function create_cli_styler(opener: number, closer: number): Styler
	local open = string.format("%c[%dm", 27, opener)
	local close = string.format("%c[%dm", 27, closer)
	return function(text: string)
		return `{open}{text}{close}`
	end
end

local function create_roblox_styler(opener: number, _: number): Styler
	--> hidden
	if opener == 8 then
		return function(text: string)
			return string.rep(" ", #text)
		end
	--> reset, inverse, overline
	elseif opener == 0 or opener == 7 or opener == 53 then
		return function(text: string)
			return text
		end
	--> bold
	elseif opener == 1 then
		return function(text: string)
			return `<b>{text}</b>`
		end
	--> italic
	elseif opener == 3 then
		return function(text: string)
			return `<i>{text}</i>`
		end
	--> underline
	elseif opener == 4 then
		return function(text: string)
			return `<u>{text}</u>`
		end
	--> strikethrough
	elseif opener == 9 then
		return function(text: string)
			return `<s>{text}</s>`
		end
	end

	local richtext_tag = RICHTEXT_TAGS[opener]
	return function(text: string)
		return `<font {richtext_tag}>{text}</font>`
	end
end

local function create_styler(opener: number, closer: number): Styler
	--stylua: ignore
    return RUNTIME == "Roblox" 
        and create_roblox_styler(opener, closer) 
        or create_cli_styler(opener, closer)
end

local function combine_styles(...: Styler): Styler
	local styles = { ... }

	return function(text: string): string
		local result = text
		for _, style in styles do
			result = style(result)
		end

		return result
	end
end

return table.freeze({
	combine = combine_styles,
	modifer = table.freeze({
		dim = create_styler(2, 22),
		bold = create_styler(1, 22),
		italic = create_styler(3, 23),
		hidden = create_styler(8, 28),
		inverse = create_styler(7, 27),
		overline = create_styler(53, 55),
		underline = create_styler(4, 24),
		strikethrough = create_styler(9, 29),
		reset = create_styler(0, 0),
	}),
	color = table.freeze({
		red = create_styler(31, 39),
		blue = create_styler(34, 39),
		cyan = create_styler(36, 39),
		gray = create_styler(90, 39),
		grey = create_styler(90, 39),
		black = create_styler(30, 39),
		green = create_styler(32, 39),
		white = create_styler(37, 39),
		yellow = create_styler(33, 39),
		purple = create_styler(35, 39),
		bright_red = create_styler(91, 39),
		bright_blue = create_styler(94, 39),
		bright_cyan = create_styler(96, 39),
		bright_green = create_styler(92, 39),
		bright_white = create_styler(97, 39),
		bright_yellow = create_styler(93, 39),
		bright_purple = create_styler(95, 39),
	}),
})
