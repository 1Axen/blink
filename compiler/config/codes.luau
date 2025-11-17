local id = 0

local function next_id(): number
	local current = id
	id += 1
	return current
end

local function next_category(): number
	id /= 1000
	id *= 1000
	id += 1000
	return id
end

next_category()

local parser = {}
parser.UnexpectedToken = next_id()
parser.DuplicateEntry = next_id()
parser.MissingEntry = next_id()
parser.SyntaxError = next_id()

local analysis = {}
analysis.Shadow = next_category()
analysis.InvalidUnion = next_id()
analysis.InvalidRange = next_id()
analysis.InvalidOption = next_id()
analysis.DuplicateEntry = next_id()
analysis.UnknownOption = next_id()
analysis.ReservedIdentifier = next_id()
analysis.InvalidImport = next_id()
analysis.DuplicateOption = next_id()

local type_checking = {}
type_checking.InvalidType = next_category()
type_checking.OptionalInMap = next_id()
type_checking.UnknownReference = next_id()
type_checking.UnrepresentableRange = next_id()
type_checking.LessGenericsParameters = next_id()
type_checking.ExtraGenericsParameters = next_id()
type_checking.InvalidGenericParameter = next_id()
type_checking.SelfRecursiveType = next_id()

type_checking.InvalidAttribute = next_id()
type_checking.FewAttributeParameters = next_id()
type_checking.ExtraAttributeParameters = next_id()

return table.freeze({
	parser = parser,
	analysis = analysis,
	type_checking = type_checking,
})
