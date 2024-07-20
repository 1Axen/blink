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

type Line = {
    span: span.Span,
    index: number,
}

type Group = {
    span: span.Span,
    labels: {LabelState}
}

type LabelKind = "Inline" | "Multiline"

type LabelState = {
    kind: LabelKind,
    span: span.Span,
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

local GRAY = style.color.gray
local BREAK = GRAY("┆")

local function get_lines_in_span(code: string, lines: {string}, group_span: span.Span): {Line}
    local result: {Line} = {}

    local position = 1
    for line_number, line_text in lines do
        local start = position
        local finish = (position + #line_text)
        position = finish + 1

        if group_span.finish < start then
            break
        end

        if group_span.start > finish then
            continue
        end

        table.insert(result, {
            span = span.create(code, start, finish - 1),
            index = line_number,
        })
    end

    return result
end

local label = {}

function label.create(span: span.Span): Label
    local kind = (string.find(span.text, "\n") and "Multiline" or "Inline")
    local state: LabelState = {
        kind = kind :: LabelKind,
        span = span,
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

function report.create(kind: ReportKind, file: string, code: string): Report
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

        local lines = string.split(code, "\n")
        local result_builder = builder.create()

        --> Build report header
        local kind_header: string
        if kind == "Error" then
            kind_header = style.color.red(string.format("[E%02i] Error:", state.report_code))
        elseif kind == "Warning" then
            kind_header = style.color.yellow(string.format("[W%02i] Warning:", state.report_code))
        end

        result_builder.append_line("")
        result_builder.append_line(`{kind_header} {state.message}`)
        result_builder.append_line(`    {GRAY("╭─")}[{file}:1:{#lines}]`)
        result_builder.append_line(`    {GRAY("│")}`)
        --result_builder.append_line("\╭─▸")
                                              
        --> Build labels
        table.sort(state.labels, function(a, b)
            return a.span.start < b.span.start
        end)

        local groups: {Group} = {}
        for _, label in state.labels do
            local matched = false
            local label_span = label.span

            for _, group in groups do
                local group_span = group.span
                if span.intersects(group_span, label_span) then
                    matched = true
                    group.span = span.create(
                        code, 
                        math.min(group_span.start, label_span.start), 
                        math.max(group_span.finish, label_span.finish)
                    )
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
            local group_lines = get_lines_in_span(code, lines, group.span)
            local group_labels = group.labels
            for _, line in group_lines do
                local labels: {LabelState} = {}
                local line_span = line.span
                local multiline_indent = ""

                for _, label in group_labels do
                    local label_span = label.span
                    if label.kind == "Multiline" and span.intersects(line_span, label_span) then
                        local indent = "│ "
                        if label_span.start >= line_span.start then
                            indent = "╭─▸"
                        elseif label_span.finish <= line_span.finish then
                            indent = "├─▸"
                            table.insert(labels, label)
                        end

                        multiline_indent = label.color(indent)
                    elseif label_span.start >= line_span.start and label_span.finish <= line_span.finish then
                        table.insert(labels, label)
                    end
                end

                result_builder.append(`{style.color.gray(string.format("% 3i", line.index))} {GRAY("│")} {multiline_indent} `)
                result_builder.append_line(line_span.text)

                for _, label in labels do
                    local color = label.color
                    if label.kind == "Multiline" then
                        result_builder.append_line(`    {BREAK} {color("│")}`)
                        result_builder.append_line(`    {BREAK} {color("╰────")} {label.message}`)
                    elseif label.kind == "Inline" then
                        local label_span = label.span
                        local spaces = (label_span.start - line_span.start)
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
        result_builder.append_line(GRAY("────╯"))

        local report_result = result_builder.finish()

        return {
            print = function()
                print(report_result)
            end,
            error = function(stido_error: ((string) -> ())?)
                if stido_error then
                    stido_error(report_result)
                    error(state.message, 2)
                else
                    error(report_result, 2)
                end
            end
        }
    end

    return prototype
end

local any: any
export type Label = typeof(label.create(any))
export type Report = typeof(report.create(any, any, any))

return {
    style = style,
    report = report,
    label = label
}