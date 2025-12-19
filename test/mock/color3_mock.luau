local color3 = {}
color3.__index = color3

type Color3Mock = setmetatable<{
	hue: number,
	saturation: number,
	value: number,
}, typeof(color3)>

function color3.fromHSV(hue: number, saturation: number, value: number)
	return setmetatable({
		hue = hue,
		saturation = saturation,
		value = value,
	}, color3)
end

function color3.ToHSV(self: Color3Mock): (number, number, number)
	return self.hue, self.saturation, self.value
end

function color3.__eq(self: Color3Mock, value: Color3Mock)
	return self.hue == value.hue and self.saturation == value.saturation and self.value == value.value
end

function color3.__tostring(self: Color3Mock)
	return `Color3({math.deg(self.hue) // 1}, {self.saturation * 100 // 1}, {self.value * 100 // 1})`
end

return color3
