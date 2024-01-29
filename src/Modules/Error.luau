--!native
--!optimize 2

export type Token = {
    Type: any,
    Value: string,

    Start: number,
    End: number,
}

local Error = {}

--> Generates nice rust-like errors
function Error.ThrowTokenError(Source: string, Token: Token, Error: string, ...: string)
    local Hints = {...}
    local Lines = string.split(Source, "\n")

    local Seek = 1
    local Line, Slice, Spaces, Arrows;

    for Index, String in Lines do
        --> Ignore lines which are before the current one
        local LineStart = Seek
        Seek += (#String + 1)

        if Token.End >= Seek then
            continue
        end

        --> Plain search for the tokens value in the line
        local Init = 1
        local Start, End;
        while true do
            Start, End = string.find(String, Token.Value, Init, true)

            --> Prevent picking same characters from earlier in the line
            if Start and End then
                local Offset = (Token.Start - LineStart)
                if Start < Offset then
                    Init = Start + 1
                    continue
                end
            end

            if not Start or not End then
                Start = Seek - 1
                End = Seek
                warn("[Blink:Error]: Unable to find token value bounds.")
            end

            break
        end

        Line = Index
        Slice = String
        Spaces = Start
        Arrows = (End - Start + 1)

        break
    end

    error(string.format(
        `\n    |\n%03i | %s\n    |%s{#Hints > 0 and `\n- {table.concat(Hints, "\n- ")}` or ""}`,
        Line,
        Slice,
        `{string.rep(" ", Spaces)}{string.rep("^", Arrows)} {Error}.`
    ))
end

return Error