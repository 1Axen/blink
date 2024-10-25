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
            local Cached = Cache[Original] 
            if Cached ~= nil then
                return Cached
            end

            local Copy = Original
            if type(Original) == "table" then
                Copy = {}
                Cache[Original] = Copy
                
                for Key, Value in Original do
                    Copy[Clone(Key)] = Clone(Value)
                end
            end

            return Copy
        end

        return Clone(Table)
    end
}