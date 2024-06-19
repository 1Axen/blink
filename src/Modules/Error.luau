--!native
--!optimize 2

local IS_ROBLOX = (game ~= nil)

local stdio;
if not IS_ROBLOX then
    stdio = require("@lune/stdio")
end

local INVISIBLE_SPACE = `<font transparency="1">0</font>`

type Slice = {
    Line: number,
    Text: string,
    Spaces: number,
    Underlines: number,
}

export type Label = {
    Span: Span,
    Text: string,
}

type Color = "red" | "green" | "blue" | "black" | "white" | "cyan" | "purple" | "yellow" | "reset"

export type Span = {
    Start: number,
    End: number,
}

local Colors = {
    black = "rgb(0, 0, 0)",
    blue = "rgb(0, 0, 255)",
    cyan = "rgb(0, 255, 255)",
    green = "rgb(0, 255, 0)",
    purple = "rgb(163, 44, 196)",
    red = "rgb(255, 0, 0)",
    white = "rgb(255, 255, 255)",
    yellow = "rgb(255, 255, 0)",
}

local Error = {
    OnEmit = nil,

    LexerUnexpectedToken = 1001,

    ParserUnexpectedEndOfFile = 2001,
    ParserUnexpectedToken = 2002,
    ParserUnknownOption = 2003,
    ParserUnexpectedSymbol = 2004,
    ParserExpectedExtraToken = 2005,
    
    AnalyzeReferenceInvalidType = 3001,
    AnalyzeInvalidOptionalType = 3002,
    AnalyzeNestedMap = 3003,
    AnalyzeDuplicateField = 3004,
    AnalyzeReservedIdentifier = 3005,
    AnalyzeNestedScope = 3006,
    AnalyzeUnknownReference = 3007,
    AnalyzeInvalidRangeType = 3008,
    AnalyzeInvalidRange = 3009,
    AnalyzeDuplicateDeclaration = 3010,
    AnalyzeDuplicateTypeGeneric = 3011,
    AnalyzeInvalidGenerics = 3012,
    AnalyzeInvalidExport = 3013,
    AnalyzeUnknownImport = 3014,
    AnalyzeErrorWhileImporting = 3015
}

Error.__index = Error

export type Class = typeof(setmetatable({} :: {
    Labels: {Label},
    Source: {string},
    Message: string,
    
    Code: number,
    RawMessage: string,
}, Error))

local function Fix(Text: string): string
    if IS_ROBLOX then
        Text = string.gsub(Text, "%s", INVISIBLE_SPACE)
    end

    return Text
end

local function Color(Text: string, Color: Color): string
    if IS_ROBLOX then
        return `<font color="{Colors[Color]}">{Text}</font>`
    end
    return `{stdio.color(Color)}{Text}{stdio.color("reset")}`
end

function Error.GetNameFromCode(From: number): string
    for Name, Code in Error do
        if Code == From then
            return Name
        end
    end

    error(`Unknown error code: {From}`)
end

function Error.new(Code: number, Source: string, Message: string, File: string?): Class
    local Lines = string.split(Source, "\n")
    local Content = `\n{Color(`[E{string.format("%04i", Code)}] Error:`, "red")}: {Message}`
    Content ..= `\n    ╭─[{File or "input.blink"}:1:{#Lines}]`
    Content ..= "\n    │"

    return setmetatable({
        Labels = {},
        Source = Lines,
        Message = Content,

        Code = Code,
        RawMessage = Message
    }, Error)
end

function Error.Slice(self: Class, Span: Span): {Slice}
    local Slices = {}
    local Cursor = 1

    for Line, Text in self.Source do
        local Start = Cursor
        local Length = #Text

        --> Advance cursor
        --> Cursor + #Length = \n => \n + 1 = Next line
        Cursor += (Length + 1)

        --> Span end is past cursor
        if Span.Start > Cursor then
            continue
        end

        local Spaces = (Span.Start - Start)
        local Underlines = math.clamp(Span.End - Span.Start, 1, Length)

        table.insert(Slices, {
            Line = Line,
            Text = Fix(Text),
            Spaces = Spaces,
            Underlines = Underlines
        })

        if Span.End <= Cursor then
            break
        end
    end

    return Slices
end

function Error.Label(self: Class, Span: Span, Text: string, TextColor: Color): Class
    local Slices = self:Slice(Span)

    --> Analyze hook
    table.insert(self.Labels, {
        Span = Span,
        Text = Fix(Text),
    })

    --> Construct message
    for Index, Slice in Slices do
        self.Message ..= `\n{Color(string.format("%03i", Slice.Line), "black")} │ {Slice.Text}`
        if Index == #Slices then
            local Length =  (Slice.Underlines // 2) 
            local Indent = `    ┆ {string.rep(" ", Slice.Spaces)}`
            local Underlines = Color(string.rep("─", Length), TextColor)
            local ExtraIndent = string.rep(" ", Length)

            self.Message ..= `\n{Indent}{Underlines}{Color("┬", TextColor)}{Underlines}`
            self.Message ..= `\n{Indent}{ExtraIndent}{Color("│", TextColor)}`
            self.Message ..= `\n{Indent}{ExtraIndent}{Color("╰──", TextColor)} {Color(Text, TextColor)}`
        end
    end
    
    return self
end

function Error.Primary(self: Class, Span: Span, Text: string): Class
    return self:Label(Span, Text, "red")
end

function Error.Secondary(self: Class, Span: Span, Text: string): Class
    return self:Label(Span, Text, "blue")
end

function Error.Emit(self: Class): never
    self.Message ..= "\n────╯"

    --> Fix message rendering in ROBLOX
    self.Message = Fix(self.Message)

    local OnEmit: ((Class) -> ())? = Error.OnEmit
    if OnEmit then
        OnEmit(self)
    end

    error(self.Message, 2)
end

return Error