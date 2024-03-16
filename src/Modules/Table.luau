return {
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