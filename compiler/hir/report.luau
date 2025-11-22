local ast = require("@ast")
local codes = require("@config/codes")
local diagnostics = require("@util/diagnostics")
local fmt_range = require("@util/range/format")
local range = require("@util/range")
local span = require("@util/span")
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
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.InvalidType)
		.with_message(`Expected "{expected}", got "{got}" instead`)
		.with_label(
			diagnostics.label
				.create(node.span)
				.with_message(`Expected "{expected}"`)
				.with_color(diagnostics.style.color.red)
		)
		.finish()
		.error()
end

local function report_expect_one_of(node: ast.Node, expected: { string }, got: string): never
	local fmted_expected = `"{table.concat(expected, '", "')}"`
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.InvalidType)
		.with_message(`Expected one of {fmted_expected}, got "{got}" instead`)
		.with_label(
			diagnostics.label
				.create(node.span)
				.with_message(`Expected one of {fmted_expected}`)
				.with_color(diagnostics.style.color.red)
		)
		.finish()
		.error()
end

local function report_few_none_generics(node: ast.Path, expected: number): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.ExtraGenericsParameters)
		.with_message(`Type expects {expected} generic parameter(s), but none are specified`)
		.with_label(
			diagnostics.label
				.create(node.span)
				.with_message(`Add missing generic parameters list`)
				.with_color(diagnostics.style.color.red)
		)
		.finish()
		.error()
end

local function report_few_generics(node: ast.GenericsArgs, expected: number): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.LessGenericsParameters)
		.with_message(`Type expects {expected} generic parameter(s), but {#node.values} are specified`)
		.with_label(
			diagnostics.label
				.create(node.span)
				.with_message(`Add missing generic parameters`)
				.with_color(diagnostics.style.color.red)
		)
		.finish()
		.error()
end

local function report_extra_generics(node: ast.GenericsArgs, maximum: number): never
	local values = node.values
	local first_extra = values[maximum + 1]
	local final_extra = values[#values]
	local extras_span = span.merge(first_extra.span, final_extra.span)

	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.ExtraGenericsParameters)
		.with_message(`Type expects {maximum} generic parameter(s), but {#values} are specified`)
		.with_label(
			diagnostics.label
				.create(extras_span)
				.with_message(`Remove extra generic parameters`)
				.with_color(diagnostics.style.color.red)
		)
		.finish()
		.error()
end

local function report_unknown_reference(expr: ast.ExprReference): never
	local path = expr.path
	local path_str = path_to_string(expr.path)
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.UnknownReference)
		.with_message(`Unknown reference "{path_str}"`)
		.with_label(diagnostics.label.create(path.span).with_color(diagnostics.style.color.red).with_message(`Unknown reference`))
		.finish()
		.error()
end

local function report_unrepresentable_range(node: ast.Range, bounds: range.Range): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.UnrepresentableRange)
		.with_message("Range cannot be represented by the type")
		.with_label(
			diagnostics.label
				.create(node.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Range should be within {fmt_range(bounds)}`)
		)
		.finish()
		.error()
end

local function report_cyclical_type(declared_at: ast.StatType, used_at: ast.Node): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.SelfRecursiveType)
		.with_message("Self-recursive type cannot be resolved")
		.with_label(
			diagnostics.label
				.create(declared_at.span)
				.with_color(diagnostics.style.color.blue)
				.with_message("Declared here")
		)
		.with_label(
			diagnostics.label
				.create(used_at.span)
				.with_color(diagnostics.style.color.red)
				.with_message("Self-recursion here")
		)
		.finish()
		.error()
end

local function report_optional_value(expr: ast.Node): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.OptionalInMap)
		.with_message(`Optional value in map type`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Make value non optional`)
		)
		.with_note("Optionals in maps aren't representable in Luau")
		.finish()
		.error()
end

local function report_optional_indexer(expr: ast.Node): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.OptionalInMap)
		.with_message(`Optional indexer in map type`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Make indexer non optional`)
		)
		.with_note("Optionals in maps aren't representable in Luau")
		.finish()
		.error()
end

local function report_invalid_intersection(expr: ast.Node, got: TyKind, left: TyKind, right: TyKind): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.InvalidType)
		.with_message(`Cannot intersect type "{left}" and type "{right}"`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Expected type "struct", got type "{got}" instead`)
		)
		.with_note("Intersections can only be created between two structs")
		.finish()
		.error()
end

local function report_cannot_convert_type(expr: ast.Expression, expected: TyKind, got: TyKind): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.InvalidType)
		.with_message(`Cannot convert type "{got}" to type "{expected}"`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Expected type "{expected}"`)
		)
		.finish()
		.error()
end

local function report_invalid_attribute(expr: ast.Attribute): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.InvalidAttribute)
		.with_message(`Invalid attribute "@{expr.name.value}"`)
		.with_label(diagnostics.label.create(expr.span).with_color(diagnostics.style.color.red).with_message("Invalid attribute"))
		.finish()
		.error()
end

local function report_few_attribute_parameters(node: ast.Attribute, expected: number): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.LessGenericsParameters)
		.with_message(`Attribute expects {expected} parameter(s), but {#node.args} are specified`)
		.with_label(
			diagnostics.label
				.create(node.span)
				.with_message(`Add missing parameters`)
				.with_color(diagnostics.style.color.red)
		)
		.finish()
		.error()
end

local function report_extra_attribute_parameters(node: ast.Attribute, maximum: number): never
	local values = node.args
	local first_extra = values[maximum + 1]
	local final_extra = values[#values]
	local extras_span = span.merge(first_extra.span, final_extra.span)

	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.ExtraAttributeParameters)
		.with_message(`Attribute expects {maximum} generic parameter(s), but {#values} are specified`)
		.with_label(
			diagnostics.label
				.create(extras_span)
				.with_message(`Remove extra parameters`)
				.with_color(diagnostics.style.color.red)
		)
		.finish()
		.error()
end

local function report_cannot_represent_vector_axis(expr: ast.Node): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.InvalidGenericParameter)
		.with_message(`Luau cannot represent vector axes types larger than a f32`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Use a smaller numeral type`)
		)
		.finish()
		.error()
end

local function report_unknown_option(stat: ast.StatOption): never
	local name = stat.name
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.UnknownOption)
		.with_message(`Unknown option "{name.value}"`)
		.with_label(
			diagnostics.label
				.create(name.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`"{name.value}" is not a valid option`)
		)
		.finish()
		.error()
end

local function report_duplicate_option(caster: ast.StatOption, shaded: ast.StatOption): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.DuplicateOption)
		.with_message(`Duplicate option declaration`)
		.with_label(
			diagnostics.label
				.create(caster.span)
				.with_color(diagnostics.style.color.red)
				.with_message("Duplicate declaration here")
		)
		.with_label(
			diagnostics.label
				.create(shaded.span)
				.with_color(diagnostics.style.color.cyan)
				.with_message("Previously declared here")
		)
		.finish()
		.error()
end

local function report_invalid_option_type(stat: ast.StatOption, expected_kind: string): never
	local value_expr = stat.value
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.InvalidOption)
		.with_message(`Option "{stat.name.value}" expects a value of kind "{expected_kind}"`)
		.with_label(
			diagnostics.label
				.create(value_expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Expected a value of kind "{expected_kind}", got "{value_expr.kind}" instead`)
		)
		.finish()
		.error()
end

local function report_invalid_option_value(stat: ast.StatOption, expected_values: { any }): never
	local possible_values = `"{table.concat(expected_values, '", ')}"`
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.InvalidOption)
		.with_message(`Option "{stat.name.value}" expects one of {possible_values}`)
		.with_label(
			diagnostics.label
				.create(stat.value.span)
				.with_color(diagnostics.style.color.red)
				.with_message(`Replace with one of {possible_values}`)
		)
		.finish()
		.error()
end

local function report_duplicate_union_type(duplicate: ast.Expression, previous: ast.Expression): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.type_checking.DuplicateUnionType)
		.with_message("Duplicate tyes used in union")
		.with_label(
			diagnostics.label
				.create(duplicate.span)
				.with_color(diagnostics.style.color.red)
				.with_message("Duplicate type here")
		)
		.with_label(
			diagnostics.label
				.create(previous.span)
				.with_color(diagnostics.style.color.cyan)
				.with_message("Previous type here")
		)
		.finish()
		.error()
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

	duplicate_union_type = report_duplicate_union_type,
})
