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

local analysis = {}
analysis.Shadow = next_category()
analysis.InvalidUnion = next_id()
analysis.InvalidRange = next_id()
analysis.InvalidOption = next_id()
analysis.OptionalInMap = next_id()
analysis.DuplicateEntry = next_id()
analysis.UnknownOption = next_id()
analysis.UnknownReference = next_id()
analysis.GenericsParameters = next_id()
analysis.ReservedIdentifier = next_id()
analysis.UnrepresentableRange = next_id()

return table.freeze({
    parser = parser,
    analysis = analysis
})