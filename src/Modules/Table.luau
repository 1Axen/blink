return {
    DeepClone = function(Table: {[any]: any}): {[any]: any}
        local function Clone(Source: {[any]: any})
            local Result = {}
            for Index, Value in Source do
                if type(Value) == "table" then
                    Result[Index] = Clone(Value)
                else
                    Result[Index] = Value
                end
            end

            return Result
        end

        return Clone(Table)
    end
}