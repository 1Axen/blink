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
        local Cache = {}
        local function Clone(Original)
            local Copy = Original
            if type(Original) == "table" then
                if Cache[Original] then
                    Copy = Cache[Original]
                else
                    Copy = {}
                    Cache[Original] = Copy
                    
                    for Key, Value in Original do
                        Copy[Clone(Key)] = Clone(Value)
                    end
                end
            end

            Cache[Original] = Copy
            return Copy
        end

        return Clone(Table)
    end
}