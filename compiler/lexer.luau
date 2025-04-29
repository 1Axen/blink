--!strict
--!native
--!optimize 2

local file = require("@util/file")
local span = require("@util/span")

export type TokenBase<Kind> = {
    read kind: Kind,
    read span: vector,
}

export type Token = 
    --> words
    | TokenBase<"word">
    | TokenBase<"as">
    | TokenBase<"set">
    | TokenBase<"map">
    | TokenBase<"enum">
    | TokenBase<"type">
    | TokenBase<"scope">
    | TokenBase<"event">
    | TokenBase<"struct">
    | TokenBase<"option">
    | TokenBase<"export">
    | TokenBase<"import">
    | TokenBase<"function">

    --> literals
    | TokenBase<"true">
    | TokenBase<"false">
    | TokenBase<"number">
    | TokenBase<"string">

    --> symbols
    | TokenBase<"@">
    | TokenBase<".">
    | TokenBase<"=">
    | TokenBase<":">
    | TokenBase<",">
    | TokenBase<"&">
    | TokenBase<"?">
    | TokenBase<"..">

    --> delimiters
    | TokenBase<"{">
    | TokenBase<"<">
    | TokenBase<"(">
    | TokenBase<"[">
    | TokenBase<"}">
    | TokenBase<">">
    | TokenBase<")">
    | TokenBase<"]">

    | TokenBase<"error">
    | TokenBase<"eof">

export type TokenKind = index<Token, "kind">

local NULL = 0

local DOT = string.byte(".")
local QOUTE = string.byte("\"")
local HYPHEN = string.byte("-")
local UNDERSCORE = string.byte("_")

local NEW_LINE = string.byte("\n")
local CARRIAGE_RETURN = string.byte("\r")

local SQUARE_OPEN = string.byte("[")
local SQUARE_CLOSE = string.byte("]")

local function is_whitespace(byte: number): boolean
    return byte == string.byte(" ") 
        or byte == string.byte("\t")
        or byte == NEW_LINE
        or byte == CARRIAGE_RETURN
        or byte == string.byte("\v")
        or byte == string.byte("\f")
end

local function is_letter(byte: number): boolean
    return (string.byte("a") <= byte and byte <= string.byte("z"))
        or (string.byte("A") <= byte and byte <= string.byte("Z"))
end

local function is_digit(byte: number): boolean
    return string.byte("0") <= byte and byte <= string.byte("9")
end

local function tokenize(input: file.File): {Token}
    local id = input.id
    local length = file.length(input)
    local content = input.buffer

    --> lexer state
    local position = 0

    local function peek(): number
        if position == length then
            return 0
        end
    
        return buffer.readu8(content, position)
    end

    local function lookahead(amount: number?): number
        amount = amount or 1
        
        local offset = (position + amount)
        if offset >= (length - 1) then
            return 0
        end

        return buffer.readu8(content, offset)
    end
    
    local function advance()
        position = math.min(position + 1, length) :: number
    end

    local function advance_peek(): number
        advance()
        return peek()
    end
    
    local function to_string(start_position: number)
        return buffer.readstring(content, start_position, position - start_position)
    end
    
    local function last_position(): number
        return (position - 1)
    end

    local tokens: {Token} = table.create(64) :: any

    local function create_token(kind: TokenKind, span: span.Span): Token
        return { kind = kind, span = span } :: Token
    end
    
    local function next_token(): Token?
        local first = peek()
        local start = position

        --> eof
        if first == 0 then
            return create_token("eof" :: "eof", span.create(start, start, id))
        end

        --> whitespace is lost when lexed, lossy lexer :(
        if is_whitespace(first) then
            --> keep clearing whitespace
            local char = first :: number
            repeat
                char = advance_peek()
            until not (is_whitespace(char))

            return nil
        --> comments are also lost when lexed, double lossy lexer :((
        elseif first == HYPHEN and lookahead() == HYPHEN then
            local char = peek()
            if lookahead(2) == SQUARE_OPEN and lookahead(3) == SQUARE_OPEN then
                -- keep track of how many consecutive closing square brackets we encounter
                local counter = 0

                repeat
                    if char == SQUARE_CLOSE then
                        counter += 1
                    else
                        counter = 0
                    end

                    char = advance_peek()
                until (counter == 2 or char == NULL)

                return nil
            end

            repeat
                char = advance_peek()
            until (char == NEW_LINE or char == CARRIAGE_RETURN or char == NULL)

            return nil
        --> word, can't start with numeral
        elseif is_letter(first :: number) or first == UNDERSCORE then
            --> consume full word
            local char = first :: number
            repeat
                char = advance_peek()
            until not (is_letter(char) or is_digit(char :: number) or char == UNDERSCORE)
            
            local finish = last_position()
            local value = to_string(start)
            local value_span = span.create(start, finish, id)
            
            if 
                value == "set"
                or value == "as"
                or value == "map"
                or value == "type"
                or value == "enum"
                or value == "true"
                or value == "false"
                or value == "event"
                or value == "scope"
                or value == "struct"
                or value == "option"
                or value == "export"
                or value == "import"
                or value == "function"
            then
                return create_token(value :: TokenKind, value_span)
            end

            return create_token("word" :: "word", value_span)
        elseif is_digit(first :: number) or first == HYPHEN then
            local char = first :: number
            local decimal = false

            if char == HYPHEN then
                char = advance_peek()
            end

            repeat
                if char == DOT then
                    if is_digit(lookahead()) == false then
                        break
                    end

                    decimal = true
                end

                char = advance_peek()
            until not (is_digit(char) or char == UNDERSCORE or (char == DOT and decimal == false))

            local finish = last_position()
            return create_token("number" :: "number", span.create(start, finish, id))
        elseif first == QOUTE then
            local char = advance_peek()
            while char ~= 0 and char ~= QOUTE do
                char = advance_peek()
            end

            advance()

            local finish = last_position()
            
            -- we don't care about the quotation marks
            return create_token("string" :: "string", span.create(start + 1, finish - 1, id))
        end

        advance()
        
        local value_span = span.create(start, start, id)
        if first == string.byte("{") then
            return create_token("{" :: "{", value_span)
        elseif first == string.byte("<") then
            return create_token("<" :: "<", value_span)
        elseif first == string.byte("(") then
            return create_token("(" :: "(", value_span)
        elseif first == string.byte("[") then
            return create_token("[" :: "[", value_span)
        elseif first == string.byte("}") then
            return create_token("}" :: "}", value_span)
        elseif first == string.byte(">") then
            return create_token(">" :: ">", value_span)
        elseif first == string.byte(")") then
            return create_token(")" :: ")", value_span)
        elseif first == string.byte("]") then
            return create_token("]" :: "]", value_span)
        elseif first == string.byte(":") then
            return create_token(":" :: ":", value_span)
        elseif first == string.byte(",") then
            return create_token("," :: ",", value_span)
        elseif first == string.byte("?") then
            return create_token("?" :: "?", value_span)
        elseif first == string.byte("=") then
            return create_token("=" :: "=", value_span)
        elseif first == DOT then
            if peek() == DOT then
                advance()
                return create_token(".." :: "..", span.create(start, last_position(), id))
            end

            return create_token("." :: ".", value_span)
        elseif first == string.byte("&") then
            return create_token("&" :: "&", value_span)
        elseif first == string.byte("@") then
            return create_token("@" :: "@", value_span)
        end

        return create_token("error" :: "error", value_span)
    end

    while true do
        local token = next_token()
        if token == nil then
            continue
        end

        table.insert(tokens, token)
          
        --> end of file
        if token.kind == "eof" then
            break
        end
    end

    return tokens
end

return table.freeze({
    tokenize = tokenize
})