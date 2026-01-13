local span = require("@util/span")
local style = require("@util/style")

type Span = span.Span
type Styler = style.Styler

export type Label = {
	read span: Span,
	style: Styler?,
	message: string?,
}

--stylua: ignore
export type DiagnosticKind = 
	| "Error"
	| "Warning"
	| "Info"

export type Diagnostic = {
	read kind: DiagnosticKind,
	read code: number,
	message: string?,
	labels: { Label },
	notes: { string },
}

return nil
