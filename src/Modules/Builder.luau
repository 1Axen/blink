--!native
--!optimize 2

local Builder = {}

function Builder.new(String: string?, BaseIndentation: number?): Builder
    local String = String or ""
    local Indentation = (BaseIndentation or 0)

    local function GetIndentation(Tabs: number?): string
        return string.rep("\t", Indentation + (Tabs or 0))
    end

    return {
        Push = function(Text: string, Returns: number?, Tabs: number?)
            String ..= (GetIndentation(Tabs) .. Text .. string.rep("\n", Returns or 1))
        end,

        PushFront = function(Text: string, Returns: number?, Tabs: number?)
            String = (GetIndentation(Tabs) .. Text .. string.rep("\n", Returns or 1)) .. String
        end,

        PushLines = function(Lines: {string}, Returns: number?, Tabs: number?)
            local Indent = GetIndentation(Tabs)
            local Last = Lines[#Lines]
            if string.gsub(Last, "%c", "") == "" then
                table.remove(Lines, #Lines)
            end

            for Index, Line in Lines do
                String ..= Indent .. Line .. "\n"
            end

            String ..= string.rep("\n", Returns or 0)
        end,

        SetIndentation = function(NewIndentation: number)
            Indentation = NewIndentation
        end,

        Print = function()
            print(String)
        end,

        DumpNoClear = function()
            return String
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