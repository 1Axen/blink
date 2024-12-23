local style = require("@util/style")
local panic = require("@util/panic")

local function fmt_number(number: number): string
    local stringified = tostring(number)
    return style.color.yellow(stringified)
end

local function fmt_string(str: string): string
    local with_quotation_marks = `"{str}"`
    return style.color.green(with_quotation_marks)
end

local function fmt_boolean(boolean: boolean): string
    local stringified = tostring(boolean)
    return style.color.purple(stringified)
end

local function fmt_any(any: number | string | boolean): string
    if type(any) == "number" then
        return fmt_number(any)
    elseif type(any) == "string" then
        return fmt_string(any)
    elseif type(any) == "boolean" then
        return fmt_boolean(any)
    end

    return panic(`Unhandled primitive {type(any)}`)
end


return table.freeze({
    any = fmt_any,
    number = fmt_number,
    string = fmt_string,
    boolean = fmt_boolean,
})


