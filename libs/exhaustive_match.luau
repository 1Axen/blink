local panic = require("@util/panic")

local function exhuastive_match(variant: never)

end

local function exhaustive_match_panic(variant: never): never
    return panic(`Unmatched enum value: {variant}`)
end

return table.freeze({
    run_time = exhaustive_match_panic,
    type_only = exhuastive_match,
})