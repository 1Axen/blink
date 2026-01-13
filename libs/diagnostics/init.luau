local render = require("@self/render")
local span = require("@util/span")
local style = require("@util/style")
local types = require("@self/types")

type Span = span.Span
type Styler = style.Styler

local label = {}
label.__index = label

export type Label = setmetatable<types.Label, typeof(label)>

function label.with_style(self: Label, style: Styler)
	self.style = style
	return self
end

function label.with_message(self: Label, message: string)
	self.message = message
	return self
end

local function create_label(span: Span): Label
	return setmetatable({
		span = span,
		style = nil :: Styler?,
		message = nil :: string?,
	}, label)
end

local diagnostic = {}
diagnostic.__index = diagnostic

type DiagnosticKind = types.DiagnosticKind
export type Diagnostic = setmetatable<types.Diagnostic, typeof(diagnostic)>

function diagnostic.with_message(self: Diagnostic, message: string)
	self.message = message
	return self
end

function diagnostic.with_label(self: Diagnostic, label: Label)
	table.insert(self.labels, label)
	return self
end

function diagnostic.with_note(self: Diagnostic, note: string)
	table.insert(self.notes, note)
	return self
end

function diagnostic.render(self: Diagnostic): string
	return render(self)
end

function diagnostic.print(self: Diagnostic)
	print(self:render())
end

function diagnostic.error(self: Diagnostic, level: number?): never
	error(self:render(), level)
end

function create_diagnostic(kind: DiagnosticKind, code: number): Diagnostic
	return setmetatable({
		kind = kind,
		code = code,
		message = nil :: string?,
		labels = {},
		notes = {},
	}, diagnostic)
end

return table.freeze({
	label = create_label,
	error = function(code: number)
		return create_diagnostic("Error", code)
	end,
	warning = function(code: number)
		return create_diagnostic("Warning", code)
	end,
	info = function(code: number)
		return create_diagnostic("Info", code)
	end,
})
