local range = require("@util/range")

return table.freeze({
	map = range.from_usize(32),
	array = range.from_usize(32),
})
