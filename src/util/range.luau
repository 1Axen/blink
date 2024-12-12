--!strict
--!native
--!optimize 2

export type Range = {
    min: number,
    max: number
}

local function create(min: number, max: number): Range
    return table.freeze({
        min = min,
        max = max
    })
end

return table.freeze({
    create = create
})