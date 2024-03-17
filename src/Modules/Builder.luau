--!native
--!optimize 2

local Builder = {}

function Builder.new(): Builder
    local Strings = table.create(512)
    
    local function PushLines(Lines: {string}, Returns: number?, Tabs: number?)
        local Size = #Lines
        local Last = Lines[Size]

        local Tabs = Tabs or 0
        local Returns = Returns or 0

        --> FAST PATH :SUNGLASSES:
        if Tabs == 0 and Returns == 0 then
            table.move(Lines, 1, Size, #Strings + 1, Strings)
            return
        end

        local Indentation = string.rep("\t", Tabs)

        if Last == "" then
            Size -= 1
            Lines[Size] = nil
        end

        for Index, Line in Lines do
            table.insert(Strings, `{Indentation}{Line}{Index == Size and string.rep("\n", Returns) or ""}`)
        end
    end

    return {
        Push = function(Text: string, Returns: number?, Tabs: number?)
            table.insert(Strings, `{string.rep("\t", Tabs or 0)}{Text}\n{string.rep("\n", Returns or 0)}`)
        end,

        PushFront = function(Text: string, Returns: number?, Tabs: number?)
            table.insert(Strings, `{string.rep("\n", Returns or 1)}{Text}{string.rep("\t", Tabs or 0)}\n`)
        end,

        PushLines = PushLines,
        PushMultiline = function(Text: string, Returns: number?, Tabs: number?)
            PushLines(string.split(Text, "\n"), Returns, Tabs)
        end,

        Print = function()
            print(table.concat(Strings))
        end,

        DumpNoClear = function()
            return table.concat(Strings)
        end,

        Dump = function(): string
            local Text = table.concat(Strings)
            table.clear(Strings)
            return Text
        end,

        DumpLines = function(): {string}
            return Strings
        end
    }
end

export type Builder = typeof(Builder.new())

return Builder