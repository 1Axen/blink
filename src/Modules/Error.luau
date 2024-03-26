--!native
--!optimize 2

local IS_ROBLOX = (game ~= nil)

local stdio;
if not IS_ROBLOX then
    stdio = require("@lune/stdio")
end

local SPACE = " "
local INDENT = "    "
local INVISIBLE_SPACE = `<font transparency="1">0</font>`

--> ROBLOX is ROBLOX and renders spaces at half width
if IS_ROBLOX then
    SPACE = INVISIBLE_SPACE
    INDENT = string.rep(INVISIBLE_SPACE, #INDENT)
end

type Slice = {
    Line: number,
    Text: string,
    Spaces: number,
    Underlines: number,
}

export type Label = {
    Span: Span,
    Text: string,
    Type: "Primary" | "Secondary"
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
    AnalyzeInvalidExport = 3013
}

Error.__index = Error

export type Class = typeof(setmetatable({} :: {
    Labels: {Label},
    Source: {string},
    Message: string,
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

function Error.new(Code: number, Source: string, Message: string): Class
    local Content = `{Color(`error[{Code}]`, "red")}:{SPACE}{Fix(Message)}`
    Content ..= `\n{INDENT}┌─{SPACE}input.blink`

    return setmetatable({
        Labels = {},
        Source = string.split(Source, "\n"),
        Message = Content
    }, Error)
end

function Error.Slice(self: Class, Span: Span): Slice
    local Cursor = 1
    for Line, Text in self.Source do
        local Start = Cursor
        local Length = #Text

        --> Advance cursor
        --> Cursor + #Length = \n => \n + 1 = Next line
        Cursor += (Length + 1)

        --> Span end is past cursor
        if Span.End >= Cursor then
            continue
        end

        local Spaces = (Span.Start - Start)
        local Underlines = math.clamp(Span.End - Span.Start, 1, Length)

        return {
            Line = Line,
            Text = Fix(Text),
            Spaces = Spaces,
            Underlines = Underlines
        }
    end

    error("Unable to find span bounds.")
end

function Error.Primary(self: Class, Span: Span, Text: string): Class
    local Slice = self:Slice(Span)

    --> Analyze hook
    table.insert(self.Labels, {
        Span = Span,
        Text = Text,
        Type = "Primary"
    })

    --> Construct message
    self.Message ..= `\n{Color(string.format("%03i", Slice.Line), "blue")}{SPACE}│{SPACE}{Slice.Text}`
    self.Message ..= `\n{INDENT}│{SPACE}{string.rep(SPACE, Slice.Spaces)}{Color(`{string.rep("^", Slice.Underlines)}{SPACE}{Fix(Text)}`, "red")}`

    return self
end

function Error.Secondary(self: Class, Span: Span, Text: string): Class
    local Slice = self:Slice(Span)

    --> Analyze hook
    table.insert(self.Labels, {
        Span = Span,
        Text = Text,
        Type = "Secondary"
    })

    --> Construct message
    self.Message ..= `\n{Color(string.format("%03i", Slice.Line), "blue")}{SPACE}│{SPACE}{Slice.Text}`
    self.Message ..= `\n{INDENT}│{SPACE}{string.rep(SPACE, Slice.Spaces)}{Color(`{string.rep("^", Slice.Underlines)}{SPACE}{Fix(Text)}`, "blue")}`

    return self
end

function Error.Emit(self: Class): never
    local OnEmit: (({Label}) -> ())? = Error.OnEmit
    if OnEmit then
        OnEmit(self.Labels)
    end

    error(self.Message, 2)
end

return Error