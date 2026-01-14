local ast = require("@compiler/ast")
local diagnostics = require("@util/diagnostics")
local file = require("@util/file")
local lexer = require("@compiler/lexer")
local parser = require("@compiler/parser")
local span = require("@util/span")
local style = require("@util/style")

type Ast = ast.Ast
type File = file.File
type Tiniest = typeof(require("@vendor/tiniest/tiniest_for_lute").configure({}))

local TEMPLATE_ONE = [[
type foo = "😂"

type entity<C, T> = struct {
    id: u8,
    class: C,
    health: u8,
    data: T
}

type bar = struct {
	field: u8
}
]]

local TEMPLATE_TWO = [[
type state =
    "Idle"
    | "Running"
    | "Jumping"
    | "Falling"
]]

local function from_source(name: string, source: string): Ast
	local new_file = file.from_source(name, source)
	local tokens = lexer.tokenize(new_file)
	local ast = parser.parse(new_file, tokens)
	return ast
end

return function(tiniest: Tiniest)
	local test = tiniest.test
	local snapshot = tiniest.snapshot

	local ast_one = from_source("file1.blink", TEMPLATE_ONE)
	local ast_two = from_source("file2.blink", TEMPLATE_TWO)

	local entity_statment = ast_one.body.statements[2] :: ast.StatType
	local entity_fields = (entity_statment.value :: ast.ExprStruct).fields
	local entity_fields_span = span.merge(entity_fields[1].span, entity_fields[#entity_fields].span)

	test("template", function()
		--stylua: ignore
		local result = diagnostics
			.error(0)
			:with_message("hello")
			:with_label(
				diagnostics.label((ast_one.body.statements[1] :: ast.StatType).value.span)
					:with_message("utf8")
					:with_style(style.color.green)
			)
			:with_label(diagnostics.label(entity_statment.name.span)
					:with_message("identifier")
					:with_style(style.color.blue)
			)
			:with_label(diagnostics.label(assert(entity_statment.generics).span)
					:with_message("generics")
					:with_style(style.color.yellow)
			)
			:with_label(diagnostics.label(entity_fields_span)
					:with_message("fields")
					:with_style(style.color.cyan)
			)
			:with_label(diagnostics.label(entity_fields_span)
					:with_message("fields")
					:with_style(style.color.yellow)
			)
			:with_label(diagnostics.label(entity_fields_span)
					:with_style(style.color.green)
			)
			:with_label(diagnostics.label((ast_one.body.statements[3] :: ast.StatType).value.span)
					:with_message("struct")
					:with_style(style.color.red)
			)
			:with_label(
				diagnostics.label(ast_one.body.statements[2].span)
					:with_message("statement")
					:with_style(style.color.purple)
			)
			:with_label(
				diagnostics.label(ast_two.body.statements[1].span)
					:with_message("second file statement")
					:with_style(style.modifer.bold)
			)
			:with_note("a note")
			:render()

		snapshot(result)
	end)
end
