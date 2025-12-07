export type Styler = (text: string) -> string

local function createStylerFunction(opener: number, closer: number): Styler
	local open = string.format("\x1b[%dm", opener)
	local close = string.format("\x1b[%dm", closer)

	return function(text: string)
		return `{open}{text}{close}`
	end
end

local function combineStyles(styleArray: { (text: string) -> string }): Styler
	return function(text: string)
		local result = text

		for _, style in styleArray do
			result = style(result)
		end

		return result
	end
end

local colors = {
	red = createStylerFunction(31, 39),
	blue = createStylerFunction(34, 39),
	cyan = createStylerFunction(36, 39),
	gray = createStylerFunction(90, 39),
	grey = createStylerFunction(90, 39),
	black = createStylerFunction(30, 39),
	green = createStylerFunction(32, 39),
	white = createStylerFunction(37, 39),
	yellow = createStylerFunction(33, 39),
	magenta = createStylerFunction(35, 39),
	redBright = createStylerFunction(91, 39),
	blueBright = createStylerFunction(94, 39),
	cyanBright = createStylerFunction(96, 39),
	blackBright = createStylerFunction(90, 39),
	greenBright = createStylerFunction(92, 39),
	whiteBright = createStylerFunction(97, 39),
	yellowBright = createStylerFunction(93, 39),
	magentaBright = createStylerFunction(95, 39),
}

local modifiers = {
	dim = createStylerFunction(2, 22),
	reset = createStylerFunction(0, 0),
	bold = createStylerFunction(1, 22),
	italic = createStylerFunction(3, 23),
	hidden = createStylerFunction(8, 28),
	inverse = createStylerFunction(7, 27),
	underline = createStylerFunction(4, 24),
	overline = createStylerFunction(53, 55),
	strikethrough = createStylerFunction(9, 29),
}

local function randomColor(): Styler
	return colors[math.random(1, #colors)]
end

local function randomModifier(): Styler
	return modifiers[math.random(1, #modifiers)]
end

return {
	combineStyles = combineStyles,
	randomColor = randomColor,
	randomModifier = randomModifier,
	
	color = colors,
	modifier = modifiers,
}