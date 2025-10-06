--- Performs a Fisher-Yetes shuffle on the input array.
--- The shuffle is not pure as the input array is directly mutated.
local function shuffle<T>(array: { T })
	for index = #array, 2, -1 do
		local rand_index = math.random(index)
		array[index], array[rand_index] = array[rand_index], array[index]
	end
end

return shuffle
