--!strict

--> A fancy diagnostics & error reporting library based on zesterer/ariadne

local builder = require("@util/builder")
local file = require("@util/file")
local option = require("@util/option")
local span = require("@util/span")
local style = require("@util/style")

type Span = span.Span

type LabelKind = "Inline" | "Multiline"
type ReportKind = "Warning" | "Error"

type ErrorFn = (string) -> never

type Line = {
	span: Span,
	index: number,
}

type Group = {
	span: Span,
	labels: { Label },
}

type Label = {
	kind: LabelKind,
	span: Span,
	color: style.Styler,
	message: string,
}

export type Report = {
	print: () -> (),
	error: () -> never,
}

export type LabelBuilder = {
	with_color: (style.Styler) -> LabelBuilder,
	with_message: (string) -> LabelBuilder,
	finish: () -> Label,
}

export type ReportBuilder = {
	with_code: (number) -> ReportBuilder,
	with_note: (string) -> ReportBuilder,
	with_label: (LabelBuilder) -> ReportBuilder,
	with_message: (string) -> ReportBuilder,
	finish: () -> Report,
}

local GRAY = style.color.gray
local BREAK = GRAY("┆")
local DEFAULT_FILE = "input.blink"

local error_fn: ErrorFn = error :: ErrorFn

local function create_label_builder(label_span: Span): LabelBuilder
	local color = style.color.white
	local message = "Something happened"

	local label_builder = {}
	function label_builder.with_color(color: style.Styler)
		color = color
		return label_builder
	end

	function label_builder.with_message(text: string)
		message = text
		return label_builder
	end

	function label_builder.finish(): Label
		return table.freeze({
			kind = "Inline" :: any,
			span = label_span,
			color = color,
			message = message,
		}) :: Label
	end

	return table.freeze(label_builder) :: LabelBuilder
end

local function create_report_builder(kind: ReportKind): ReportBuilder
	--> builder state
	local code = 0
	local notes = {}
	local labels = {}
	local message = "Something happened"
	local file_name: string?

	local report_builder = {}
	function report_builder.with_code(report_code: number)
		code = report_code
		return report_builder
	end

	function report_builder.with_note(note: string)
		table.insert(notes, note)
		return report_builder
	end

	function report_builder.with_message(text: string)
		message = text
		return report_builder
	end

	function report_builder.with_label(label: LabelBuilder)
		local built_label = label.finish()
		if file_name == nil then
			local label_file = option.unwrap(file.from_id(built_label.span.z))
			file_name = label_file.name
		end

		table.insert(labels, built_label)
		return report_builder
	end

	function report_builder.finish()
		local report = builder.create()
		builder.append_line(report, `[{kind} {string.format("%04i", code)}] {file_name or DEFAULT_FILE}: {message}`)
		builder.indent(report)

		for _, label in labels do
			local value = span.value(label.span)
			builder.append_line(report, style.modifer.dim(`({label.span.x}..{label.span.y}:{label.span.z}) `))

			if string.find(value, "\n") then
				local lines = string.split(value :: string, "\n")
				builder.append_lines(report, lines)
			else
				builder.append_line(report, value :: string)
			end

			builder.append_line(report, label.color(`─▸ {label.message}`))
		end

		for _, note in notes do
			builder.append(report, style.color.green("Note"))
			builder.append(report, ": ")
			builder.append_line(report, note)
		end

		local display = builder.to_string(report)

		return {
			print = function()
				print(display)
			end,
			error = function(custom_error_fn: ErrorFn?): never
				if custom_error_fn then
					return custom_error_fn(display)
				end

				return error_fn(display)
			end,
		}
	end

	return table.freeze(report_builder) :: ReportBuilder
end

local function set_error_fn(new_error_fn: ErrorFn)
	error_fn = new_error_fn
end

return table.freeze({
	style = style,
	label = table.freeze({ create = create_label_builder }),
	report = table.freeze({ create = create_report_builder }),

	set_error_fn = set_error_fn,
})
