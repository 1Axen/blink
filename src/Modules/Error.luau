export type Token = {
    Type: any,
    Value: string,

    Start: number,
    End: number,
}

local Error = {}

--> Generates nice rust-like errors
function Error.ThrowTokenError(Source: string, Token: Token, Error: string)
    local Lines = string.split(Source, "\n")

    local Seek = 1
    local Line, Slice, Spaces, Arrows;

    for Index, String in Lines do
        --> Ignore lines which are before the current one
        Seek += (#String + 1)
        if Token.End > Seek then
            continue
        end

        --> Plain search for the tokens value in the line
        local Start, End = string.find(String, Token.Value, 1, true)

        if not Start or not End then
            Start = Token.Start
            End = Token.End
            warn("[DeclareNet:Error]: Unable to find token value bounds.")
        end

        Line = Index
        Slice = String
        Spaces = Start
        Arrows = (End - Start + 1)

        break
    end

    error(string.format(
        "\n    |\n%03i | %s\n    |%s",
        Line,
        Slice,
        `{string.rep(" ", Spaces)}{string.rep("^", Arrows)} {Error}.`
    ))
end

return Error