local brick_color = {}
brick_color.__index = brick_color

type BrickColorMock = setmetatable<{
	Number: number,
}, typeof(brick_color)>

function brick_color.new(index: number)
	return setmetatable({
		Number = index,
	}, brick_color)
end

function brick_color.__eq(self: BrickColorMock, value: BrickColorMock)
	return self.Number == value.Number
end

function brick_color.__tostring(self: BrickColorMock)
	return `BrickColor({self.Number})`
end

return brick_color
