return {
    Merge = function(...: {any}): {any}
        local Tables = {...}
        local Allocate = 0

        for _, Table in Tables do
            Allocate += #Table
        end

        local Index = 1
        local Merged = table.create(Allocate)

        for _, Table in Tables do
            table.move(Table, 1, #Table, Index, Merged)
            Index += #Table
        end

        return Merged
    end,

    DeepClone = function(Table: {[any]: any}): {[any]: any}
        local Clones = {}
        local function Clone(Original)
            local Result = Original
            if type(Original) == "table" then
                if Clones[Original] then
                    Result = Clones[Original]
                else
                    Result = {}
                    Clones[Original] = Result
                    for Key, Value in Original do
                        Result[Clone(Key)] = Clone(Value)
                    end
                end
            end

            return Result
        end

        return Clone(Table)
    end
}