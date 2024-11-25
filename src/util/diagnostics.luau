--!strict

-- Copyright (c) 2024 Axen

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--> A fancy diagnostics & error reporting library based on zesterer/ariadne

local span = require("./span")
local style = require("./style")
local builder = require("builder")
local location = require("location")

type Span = span.Span
type Location = location.Location

type Line = {
    span: Span,
    index: number,
}

type Group = {
    span: Span,
    labels: {LabelState}
}

type LabelKind = "Inline" | "Multiline"

type LabelState = {
    kind: LabelKind,
    span: Span,
    color: style.Styler,
    message: string,
}

type ReportState = {
    note: string?,
    labels: {LabelState},
    message: string,
    report_code: number,
}

export type ReportKind = "Warning" | "Error"
type ErrorFunction = (string) -> never

local GRAY = style.color.gray
local BREAK = GRAY("┆")
local default_error: ErrorFunction = error

local function get_lines_in_span(text: buffer, lines: {string}, group_span: Span): {Line}
    local result: {Line} = {}

    local group_start = group_span.start
    local group_finish = group_span.finish
    local position = (location.position(group_start) - location.character(group_start))

    for line_number = location.line(group_start), location.line(group_finish) do
        local line = lines[line_number]
        local length = #line
        local stripped_len = #string.gsub(line, "[\n\r]+", "")

        local start = location.create(position, line_number, 0)
        local finish = location.create(position + stripped_len, line_number, stripped_len)
        position += length + 1

        table.insert(result, {
            span = span.create(start, finish),
            index = line_number,
        })
    end

    return result
end

local label = {}

function label.create(label_span: Span): Label
    local kind = (span.is_multiline(label_span) and "Multiline" or "Inline")
    local state: LabelState = {
        kind = kind :: LabelKind,
        span = label_span,
        order = 1,
        color = style.color.white,
        message = "Something happened"
    }

    local prototype = {}
    function prototype.with_color(color: style.Styler)
        state.color = color
        return prototype
    end

    function prototype.with_message(message: string)
        state.message = message
        return prototype
    end

    function prototype.finish(): LabelState
        return table.freeze(state)
    end

    return prototype
end

local report = {}

function report.create(kind: ReportKind, file: string, input: buffer): Report
    local state: ReportState = {
        note = nil,
        labels = {},
        message = "Something happened",
        report_code = 0
    }

    local prototype = {}
    function prototype.with_code(report_code: number)
        state.report_code = report_code
        return prototype
    end

    function prototype.with_note(note: string)
        state.note = note
        return prototype
    end

    function prototype.with_message(message: string)
        state.message = message
        return prototype
    end

    function prototype.with_label(label: Label)
        table.insert(state.labels, label.finish())
        return prototype
    end

    function prototype.finish()
        --> Prevent state from being altered
        table.freeze(state)

        local lines = string.split(buffer.tostring(input), "\n")
        local result_builder = builder.create()

        --> Build report header
        local kind_header: string
        if kind == "Error" then
            kind_header = style.color.red(string.format("[E%02i] Error:", state.report_code))
        elseif kind == "Warning" then
            kind_header = style.color.yellow(string.format("[W%02i] Warning:", state.report_code))
        end

        result_builder.append_line(`{kind_header} {state.message}`)
        result_builder.append_line(`    {GRAY("╭─")}[{file}:1:{#lines}]`)
        result_builder.append_line(`    {GRAY("│")}`)
        --result_builder.append_line("\╭─▸")
                                              
        --> Build labels
        table.sort(state.labels, function(a, b)
            return location.position(a.span.start) < location.position(b.span.start)
        end)

        local groups: {Group} = {}
        for _, label in state.labels do
            local matched = false
            local label_span = label.span
            local label_start = label_span.start
            local label_finish = label_span.finish

            for _, group in groups do
                local group_span = group.span
                if span.intersects(group_span, label_span) then
                    local group_start = group_span.start
                    local group_finish = group_span.finish

                    local start = location.position(group_start) < location.position(label_start) 
                        and group_start 
                        or label_start

                    local finish = location.position(group_finish) > location.position(label_finish) 
                        and group_finish 
                        or label_finish
                    
                    matched = true
                    group.span = span.create(start, finish)
                    table.insert(group.labels, label)
                end
            end

            if matched then
                continue
            end

            table.insert(groups, {
                span = table.clone(label_span),
                labels = {label}
            })
        end

        for _, group in groups do
            local group_lines = get_lines_in_span(input, lines, group.span)
            local group_labels = group.labels

            for _, line in group_lines do
                local labels: {LabelState} = {}
                local line_span = line.span
                local line_start = location.position(line_span.start)
                local line_finish = location.position(line_span.finish)
                local multiline_indent = ""

                for _, label in group_labels do
                    local label_span = label.span
                    local label_start = location.position(label_span.start)
                    local label_finish = location.position(label_span.finish)

                    if label.kind == "Multiline" and span.intersects(line_span, label_span) then
                        local indent = "│ "
                        if label_start >= line_start then
                            indent = "╭─▸"
                        elseif label_finish <= line_finish then
                            indent = "├─▸"
                            table.insert(labels, label)
                        end

                        multiline_indent = label.color(indent)
                    elseif label_start >= line_start and label_finish <= line_finish then
                        table.insert(labels, label)
                    end
                end

                result_builder.append(`{style.color.gray(string.format("% 3i", line.index))} {GRAY("│")} {multiline_indent} `)
                result_builder.append_line(span.value(line_span, input))

                for _, label in labels do
                    local color = label.color
                    if label.kind == "Multiline" then
                        result_builder.append_line(`    {BREAK} {color("│")}`)
                        result_builder.append_line(`    {BREAK} {color("╰────")} {label.message}`)
                    elseif label.kind == "Inline" then
                        local label_span = label.span
                        local label_start = location.position(label_span.start)

                        local spaces = (label_start - line_start)
                        local underlines = span.length(label_span)

                        local first_half = (underlines - 1) // 2
                        local second_half = (underlines - 1) - first_half

                        result_builder.append_line(`    {BREAK} {multiline_indent} {string.rep(" ", spaces)}{color(string.rep("─", first_half))}{color("┬")}{color(string.rep("─", second_half))}`)
                        result_builder.append_line(`    {BREAK} {multiline_indent} {string.rep(" ", spaces + first_half)}{color("╰──")} {label.message}`)
                    end
                end
            end
        end

        --> Build note
        if state.note then
            result_builder.append_line(`    {BREAK}`)
            result_builder.append(`    {BREAK}    `)
            result_builder.append(style.combine("Note", style.color.green))
            result_builder.append_line(`: {state.note}`)
        end

        --> Finish building report
        result_builder.append_line(GRAY("    │"))
        result_builder.append(GRAY("────╯"))

        local report_result = result_builder.finish()

        return {
            print = function()
                print(report_result)
            end,
            error = function(custom_error: ErrorFunction?): never
                if custom_error then
                    return custom_error(report_result)
                end

                return default_error(report_result)
            end
        }
    end

    return prototype
end

local function set_default_error(error_function: ErrorFunction)
    default_error = error_function
end

local any: any
export type Label = typeof(label.create(any))
export type Report = typeof(report.create(any, any, any))

return table.freeze({
    style = style,
    report = report,
    label = label,

    set_default_error = set_default_error
})