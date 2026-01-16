local ast = require("@ast")
local codes = require("@config/codes")
local diagnostics = require("@util/diagnostics")
local range = require("@util/range")
local span = require("@util/span")
local style = require("@util/style")
local ty = require("@ty")

type TyKind = ty.TyKind

local function path_to_segments(path: ast.Path): { string }
	local segments: { string } = {}
	for _, segment in path.segments do
		table.insert(segments, segment.value)
	end

	return segments
end

local function path_to_string(path: ast.Path): string
	return table.concat(path_to_segments(path), ".")
end

local function report_expect(node: ast.Node, expected: string, got: string): never
	return diagnostics
		.error(codes.type_checking.InvalidType)
		:with_message(`Expected "{expected}", got "{got}" instead`)
		:with_label(diagnostics.label(node.span):with_message(`Expected "{expected}"`):with_style(style.color.red))
		:error()
end

local function report_expect_one_of(node: ast.Node, expected: { string }, got: string): never
	local fmted_expected = `"{table.concat(expected, '", "')}"`
	return diagnostics
		.error(codes.type_checking.InvalidType)
		:with_message(`Expected one of {fmted_expected}, got "{got}" instead`)
		:with_label(
			diagnostics.label(node.span):with_message(`Expected one of {fmted_expected}`):with_style(style.color.red)
		)
		:error()
end

local function report_few_none_generics(node: ast.Path, expected: number): never
	return diagnostics
		.error(codes.type_checking.ExtraGenericsParameters)
		:with_message(`Type expects {expected} generic parameter(s), but none are specified`)
		:with_label(
			diagnostics.label(node.span):with_message(`Add missing generic parameters list`):with_style(style.color.red)
		)
		:error()
end

local function report_few_generics(node: ast.GenericsArgs, expected: number): never
	return diagnostics
		.error(codes.type_checking.LessGenericsParameters)
		:with_message(`Type expects {expected} generic parameter(s), but {#node.values} are specified`)
		:with_label(
			diagnostics.label(node.span):with_message(`Add missing generic parameters`):with_style(style.color.red)
		)
		:error()
end

local function report_extra_generics(node: ast.GenericsArgs, maximum: number): never
	local values = node.values
	local first_extra = values[maximum + 1]
	local final_extra = values[#values]
	local extras_span = span.merge(first_extra.span, final_extra.span)

	return diagnostics
		.error(codes.type_checking.ExtraGenericsParameters)
		:with_message(`Type expects {maximum} generic parameter(s), but {#values} are specified`)
		:with_label(
			diagnostics.label(extras_span):with_message(`Remove extra generic parameters`):with_style(style.color.red)
		)
		:error()
end

local function report_unknown_reference(expr: ast.ExprReference): never
	local path = expr.path
	local path_str = path_to_string(expr.path)
	return diagnostics
		.error(codes.type_checking.UnknownReference)
		:with_message(`Unknown reference "{path_str}"`)
		:with_label(diagnostics.label(path.span):with_style(style.color.red):with_message(`Unknown reference`))
		:error()
end

local function report_unrepresentable_range(node: ast.Range, bounds: range.Range): never
	return diagnostics
		.error(codes.type_checking.UnrepresentableRange)
		:with_message("The specified range cannot be represented by this type")
		:with_label(
			diagnostics
				.label(node.span)
				:with_style(style.color.red)
				:with_message(`Range should be within ({bounds.min}..{bounds.max})`)
		)
		:error()
end

local function report_cyclical_type(declared_at: ast.StatType, used_at: ast.Node): never
	return diagnostics
		.error(codes.type_checking.SelfRecursiveType)
		:with_message("Self-recursive type cannot be resolved")
		:with_label(diagnostics.label(declared_at.span):with_style(style.color.blue):with_message("Declared here"))
		:with_label(diagnostics.label(used_at.span):with_style(style.color.red):with_message("Self-recursion here"))
		:error()
end

local function report_optional_value(expr: ast.Node): never
	return diagnostics
		.error(codes.type_checking.OptionalInMap)
		:with_message(`Optional value in map type`)
		:with_label(diagnostics.label(expr.span):with_style(style.color.red):with_message(`Make value non optional`))
		:with_note("Optionals in maps aren't representable in Luau")
		:error()
end

local function report_optional_indexer(expr: ast.Node): never
	return diagnostics
		.error(codes.type_checking.OptionalInMap)
		:with_message(`Optional indexer in map type`)
		:with_label(diagnostics.label(expr.span):with_style(style.color.red):with_message(`Make indexer non optional`))
		:with_note("Optionals in maps aren't representable in Luau")
		:error()
end

local function report_invalid_intersection(expr: ast.Node, got: TyKind, left: TyKind, right: TyKind): never
	return diagnostics
		.error(codes.type_checking.InvalidType)
		:with_message(`Cannot intersect type "{left}" and type "{right}"`)
		:with_label(
			diagnostics
				.label(expr.span)
				:with_style(style.color.red)
				:with_message(`Expected type "struct", got type "{got}" instead`)
		)
		:with_note("Intersections can only be created between two structs")
		:error()
end

local function report_cannot_convert_type(expr: ast.Expression, expected: TyKind, got: TyKind): never
	return diagnostics
		.error(codes.type_checking.InvalidType)
		:with_message(`Cannot convert type "{got}" to type "{expected}"`)
		:with_label(diagnostics.label(expr.span):with_style(style.color.red):with_message(`Expected type "{expected}"`))
		:error()
end

local function report_invalid_attribute(expr: ast.Attribute): never
	return diagnostics
		.error(codes.type_checking.InvalidAttribute)
		:with_message(`Invalid attribute "@{expr.name.value}"`)
		:with_label(diagnostics.label(expr.span):with_style(style.color.red):with_message("Invalid attribute"))
		:error()
end

local function report_few_attribute_parameters(node: ast.Attribute, expected: number): never
	return diagnostics
		.error(codes.type_checking.LessGenericsParameters)
		:with_message(`Attribute expects {expected} parameter(s), but {#node.args} are specified`)
		:with_label(diagnostics.label(node.span):with_message(`Add missing parameters`):with_style(style.color.red))
		:error()
end

local function report_extra_attribute_parameters(node: ast.Attribute, maximum: number): never
	local values = node.args
	local first_extra = values[maximum + 1]
	local final_extra = values[#values]
	local extras_span = span.merge(first_extra.span, final_extra.span)

	return diagnostics
		.error(codes.type_checking.ExtraAttributeParameters)
		:with_message(`Attribute expects {maximum} generic parameter(s), but {#values} are specified`)
		:with_label(diagnostics.label(extras_span):with_message(`Remove extra parameters`):with_style(style.color.red))
		:error()
end

local function report_cannot_represent_vector_axis(expr: ast.Node): never
	return diagnostics
		.error(codes.type_checking.InvalidGenericParameter)
		:with_message(`Luau cannot represent vector axes types larger than a f32`)
		:with_label(diagnostics.label(expr.span):with_style(style.color.red):with_message(`Use a smaller numeral type`))
		:error()
end

local function report_unknown_option(stat: ast.StatOption): never
	local name = stat.name
	return diagnostics
		.error(codes.analysis.UnknownOption)
		:with_message(`Unknown option "{name.value}"`)
		:with_label(
			diagnostics
				.label(name.span)
				:with_style(style.color.red)
				:with_message(`"{name.value}" is not a valid option`)
		)
		:error()
end

local function report_duplicate_option(caster: ast.StatOption, shaded: ast.StatOption): never
	return diagnostics
		.error(codes.analysis.DuplicateOption)
		:with_message(`Duplicate option declaration`)
		:with_label(
			diagnostics.label(caster.span):with_style(style.color.red):with_message("Duplicate declaration here")
		)
		:with_label(
			diagnostics.label(shaded.span):with_style(style.color.cyan):with_message("Previously declared here")
		)
		:error()
end

local function report_invalid_option_type(stat: ast.StatOption, expected_kind: string): never
	local value_expr = stat.value
	return diagnostics
		.error(codes.analysis.InvalidOption)
		:with_message(`Option "{stat.name.value}" expects a value of kind "{expected_kind}"`)
		:with_label(
			diagnostics
				.label(value_expr.span)
				:with_style(style.color.red)
				:with_message(`Expected a value of kind "{expected_kind}", got "{value_expr.kind}" instead`)
		)
		:error()
end

local function report_invalid_option_value(stat: ast.StatOption, expected_values: { any }): never
	local possible_values = `"{table.concat(expected_values, '", ')}"`
	return diagnostics
		.error(codes.analysis.InvalidOption)
		:with_message(`Option "{stat.name.value}" expects one of {possible_values}`)
		:with_label(
			diagnostics
				.label(stat.value.span)
				:with_style(style.color.red)
				:with_message(`Replace with one of {possible_values}`)
		)
		:error()
end

local function report_duplicate_union_type(
	union: ast.Expression,
	duplicate: ast.Expression,
	previous: ast.Expression
): never
	return diagnostics
		.error(codes.type_checking.DuplicateUnionType)
		:with_message("Duplicate type used in union")
		:with_label(
			diagnostics
				.label(union.span)
				:with_style(style.color.purple)
				:with_message("The duplicate type was found in this union")
		)
		:with_label(diagnostics.label(duplicate.span):with_style(style.color.red):with_message("Duplicate type here"))
		:with_label(diagnostics.label(previous.span):with_style(style.color.cyan):with_message("Previous type here"))
		:error()
end

local function report_duplicate_entry(
	expr: ast.Expression,
	previous: ast.ExprLiteral | ast.Identifier,
	duplicate: ast.ExprLiteral | ast.Identifier
): never
	local kind = expr.kind
	return diagnostics
		.error(codes.analysis.DuplicateEntry)
		:with_message(`Duplicate entry "{previous.value}" in {kind}`)
		:with_label(diagnostics.label(previous.span):with_style(style.color.cyan):with_message(`Previous entry`))
		:with_label(diagnostics.label(duplicate.span):with_style(style.color.red):with_message(`Duplicate entry`))
		:with_label(
			diagnostics
				.label(expr.span)
				:with_style(style.color.bright_purple)
				:with_message(`The duplicate entry was found in this {kind}`)
		)
		:error()
end

local function report_tag_in_variant(tag: ast.ExprString, field: ast.ExprField)
	return diagnostics
		.error(codes.analysis.ReservedIdentifier)
		:with_message(`Union tag used as a field in variant`)
		:with_label(diagnostics.label(tag.span):with_style(style.color.blue):with_message(`The union tag`))
		:with_label(
			diagnostics.label(field.name.span):with_style(style.color.red):with_message(`Change this field's name`)
		)
		:error()
end

return table.freeze({
	expect = report_expect,
	expect_one_of = report_expect_one_of,
	cannot_convert_type = report_cannot_convert_type,

	few_generics = report_few_generics,
	extra_generics = report_extra_generics,
	few_none_generics = report_few_none_generics,

	optional_value = report_optional_value,
	optional_indexer = report_optional_indexer,

	invalid_intersection = report_invalid_intersection,
	unknown_reference = report_unknown_reference,
	unrepresentable_range = report_unrepresentable_range,
	self_recursive_type = report_cyclical_type,

	cannot_represent_vector_axis = report_cannot_represent_vector_axis,

	invalid_attribute = report_invalid_attribute,
	few_attribute_parameters = report_few_attribute_parameters,
	extra_attribute_parameters = report_extra_attribute_parameters,

	unknown_option = report_unknown_option,
	duplicate_option = report_duplicate_option,
	invalid_option_type = report_invalid_option_type,
	invalid_option_value = report_invalid_option_value,

	tag_in_variant = report_tag_in_variant,
	duplicate_entry = report_duplicate_entry,
	duplicate_union_type = report_duplicate_union_type,
})
