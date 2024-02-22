--!native
--!optimize 2

local stdio = require("@lune/stdio")

local SPACE = "    "

type Slice = {
    Line: number,
    Text: string,
    Spaces: number,
    Underlines: number,
}

export type Span = {
    Start: number,
    End: number,
}

local Error = {
    LexerUnexpectedToken = 1001,

    ParserUnexpectedEndOfFile = 2001,
    ParserUnexpectedToken = 2002,
    ParserUnknownOption = 2003,
    ParserUnexpectedSymbol = 2004,
    ParserExpectedExtraToken = 2005,
    
    AnalyzePrimitiveReferencesNonPrimitive = 3001,
    AnalyzeInvalidOptionalType = 3002,
    AnalyzeNestedMap = 3003,
    AnalyzeDuplicateField = 3004,
    AnalyzeReservedIdentifier = 3005,
    AnalyzeNestedScope = 3006,
    AnalyzeUnknownReference = 3007,
    AnalyzeInvalidRangeType = 3008,
    AnalyzeInvalidRange = 3009
}

Error.__index = Error

export type Class = typeof(setmetatable({} :: {
    Source: {string},
    Message: string,
}, Error))

local function Color(Text: string, Color: stdio.Color): string
    return `{stdio.color(Color)}{Text}{stdio.color("reset")}`
end

function Error.new(Code: number, Source: string, Message: string): Class
    local Content = `{Color(`error[{Code}]`, "red")}: {Message}`
    Content ..= `\n{SPACE}┌─ input.blink`

    return setmetatable({
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
        local Underlines = math.max(1, Span.End - Span.Start)

        return {
            Line = Line,
            Text = Text,
            Spaces = Spaces,
            Underlines = Underlines
        }
    end

    error("Unable to find span bounds.")
end

function Error.Primary(self: Class, Span: Span, Text: string): Class
    local Slice = self:Slice(Span)
    self.Message ..= `\n{Color(string.format("%03i", Slice.Line), "blue")} │ {Slice.Text}`
    self.Message ..= `\n{SPACE}│ {string.rep(" ", Slice.Spaces)}{Color(`{string.rep("^", Slice.Underlines)} {Text}`, "red")}`
    return self
end

function Error.Secondary(self: Class, Span: Span, Text: string): Class
    local Slice = self:Slice(Span)
    self.Message ..= `\n{Color(string.format("%03i", Slice.Line), "blue")} │ {Slice.Text}`
    self.Message ..= `\n{SPACE}│ {string.rep(" ", Slice.Spaces)}{Color(`{string.rep("-", Slice.Underlines)} {Text}`, "blue")}`
    return self
end

function Error.Emit(self: Class): never
    error(self.Message, 2)
end

return Error