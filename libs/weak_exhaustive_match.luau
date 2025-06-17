--- Only produces a type error if passed a variant
local function weak_exhaustive_match(variant: never) end
return weak_exhaustive_match
