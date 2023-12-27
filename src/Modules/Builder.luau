local Builder = {}

function Builder.new(String: string?): Builder
    local String = String or ""
    return {
        Push = function(Text: string, Returns: number?, Tabs: number?)
            String ..= (string.rep("\t", Tabs or 0) .. Text .. string.rep("\n", Returns or 1))
        end,

        PushLines = function(Lines: {string}, Returns: number?, Tabs: number?)
            local Indent = string.rep("\t", Tabs or 0)
            table.remove(Lines, #Lines)

            for Index, Line in Lines do
                String ..= Indent .. Line .. "\n"
            end

            String ..= string.rep("\n", Returns or 0)
        end,

        Dump = function(): string
            local Text = String
            String = ""
            return Text
        end,
    }
end

export type Builder = typeof(Builder.new())

return Builder