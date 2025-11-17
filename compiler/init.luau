local hir = require("@compiler/hir")
local lexer = require("@compiler/lexer")
local lir = require("@compiler/lir")
local parser = require("@compiler/parser")

local ast = require("@self/ast/types")
local codegen = require("@self/codegen")
local codes = require("@self/config/codes")
local compilation = require("@self/config/compilation")

local diagnostics = require("@util/diagnostics")
local file = require("@util/file")
local fs = require("@util/fs")
local import_resolver = require("@util/import_resolver")
local panic = require("@util/panic")
local path = require("@util/path")
local result = require("@util/result")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local symbols = require("@compiler/symbols")
local typeforge = require("@util/typeforge")

local md5 = require("@vendor/md5")

type Ast = ast.Ast
type Symbols = ast.Symbols

type Path = path.Path
type File = file.File

type Target = compilation.Target
type Profile = compilation.Profile
type FilesMap = compilation.FilesMap

type Context = {
	symbols: Symbols,
	directory: Path,
}

export type Targets = typeforge.StringUnionToStruct<Target, {
	path: Path,
	contents: string,
}?>

export type Options = {
	profile: Profile,
}

export type Timings = {
	ast: number,
	hir: number,
	lir: number,
	codegen: number,
	total: number,
}

export type Output = {
	hir: hir.Hir,
	lir: lir.Lir,
	files: FilesMap,
	timings: Timings,
	targets: Targets,
}

type IOError = fs.IOError

--stylua: ignore
export type CompilationError = 
	| IOError

type Result<T, E> = result.Result<T, E>
export type CompilationResult = Result<Output, CompilationError>

local function report_unknown_import(err: import_resolver.UnknownImport, expr: ast.ExprString): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.InvalidImport)
		.with_message(`Unknown import: "{path.to_string(err.path)}"`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message("Unable to locate the imported file, make sure the path is correct.")
		)
		.finish()
		.error()
end

local function report_unknown_alias(err: import_resolver.UnknownAlias, expr: ast.ExprString): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.InvalidImport)
		.with_message(`Unknown alias: "@{err.alias}"`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message("The alias wasn't found in any luaurc files, make sure it's correct.")
		)
		.finish()
		.error()
end

local function report_import_io_error(err: fs.IOError, expr: ast.ExprString): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.InvalidImport)
		.with_message(`Encountered an IO error while importing "{expr.value}": {err.message}.`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message("Make sure blink has permission to read the import's file contents.")
		)
		.finish()
		.error()
end

local function file_to_ast(file: File): Ast
	local tokens = lexer.tokenize(file)
	return parser.parse(file, tokens)
end

--[=[
    Takes an entry file and builds a map of all files imported.

    @param `file` - The entry file from which to compile.
    @param `file_path` - An absolute path to the entry file.
    @return `files` - A map of `file id` to AST
]=]
local function file_to_files_map(entry_file: File, entry_path: Path): FilesMap
	--[[
        Recursively goes through all files in the import chain.
        Whenever an import is encountered it's resolved and parsed.
        Once parsed its symbols are added to the symbols of the importing scope.
        Note that already parsed files are cached using the files map.
    ]]

	local files: FilesMap = {}
	local process_file: (file: File, file_path: Path) -> Symbols

	local function stat_import(ctx: Context, stat: ast.StatImport): never?
		--- import `path`
		local path_expr = stat.path
		local name_ident = stat.name

		local import_path = path.from_string(path_expr.value)
		local import_result = import_resolver.resolve(ctx.directory, import_path)

		if import_result.ok == false then
			local err = import_result.error
			if err.kind == "IOError" then
				return report_import_io_error(err, path_expr)
			elseif err.kind == "UnknownAlias" then
				return report_unknown_alias(err, path_expr)
			elseif err.kind == "UnknownImport" then
				return report_unknown_import(err, path_expr)
			end

			return strong_exhaustive_match(err.kind)
		end

		local import = import_result.value
		local import_file = import.file
		import_path = import.path

		local file_stem = path.file_stem(import.path)
		if file_stem == nil then
			return panic(`Unable to extract file stem from path "{path_expr.value}"`)
		end

		local import_name = file_stem
		if name_ident ~= nil then
			import_name = name_ident.value
		end

		local import_symbols = process_file(import_file, import_path)
		symbols.reference(ctx.symbols, import_symbols, import_name :: string)

		return nil
	end

	local function node_block(ctx: Context, block: ast.Block)
		for _, statement in block.statements do
			if statement.kind == "scope" then
				node_block(ctx, statement.body)
			elseif statement.kind == "import" then
				stat_import(ctx, statement)
			end
		end
	end

	function process_file(file: File, file_path: Path): Symbols
		local file_id = file.id
		local cached = files[file_id]

		if cached then
			return cached.symbols
		end

		local ast = file_to_ast(file)
		local symbols = ast.symbols
		local directory = path.strip_file_name(file_path)

		local context: Context = {
			symbols = symbols,
			directory = directory,
		}

		-- resolve imports
		node_block(context, ast.body)

		-- cache ast for future use
		files[file_id] = ast

		return symbols
	end

	-- entry file
	process_file(entry_file, entry_path)

	return files
end

--[=[
    Takes a path to a file to compile.
    @param `file_path` - An absolute path to the file which to compile.
]=]
local function compile_from_path(entry_path: Path, compiler_options: Options): CompilationResult
	local read_result = fs.read_file(entry_path)
	if read_result.ok == false then
		return read_result
	end

	local ast_pin = os.clock()
	local files = file_to_files_map(read_result.value, entry_path)
	local ast_elapsed = (os.clock() - ast_pin)

	local hir_pin = os.clock()
	local files_hir = hir.from_files(files)
	local hir_elapsed = (os.clock() - hir_pin)

	-- print(fmt_hir(files_hir))

	local lir_pin = os.clock()
	local files_lir = lir.from_hir(files_hir)
	local lir_elapsed = (os.clock() - lir_pin)

	-- print(fmt_lir(files_lir))

	local codegen_pin = os.clock()
	local targets: Targets = {}
	do
		local codegen_props: codegen.Props = {
			lir = files_lir,
			hash = md5(tostring(os.clock())),
			profile = compiler_options.profile,
		}

		local entry_options = files_hir.options[0]
		if entry_options == nil then
			return panic("Unable to retrieve the entry file's options")
		end

		if entry_options.types_output then
			targets.types = {
				path = path.from_string(entry_options.types_output),
				contents = codegen.from_lir(codegen_props, "types"),
			}
		end

		if entry_options.client_output then
			targets.client = {
				path = path.from_string(entry_options.client_output),
				contents = codegen.from_lir(codegen_props, "client"),
			}
		end

		if entry_options.server_output then
			targets.server = {
				path = path.from_string(entry_options.server_output),
				contents = codegen.from_lir(codegen_props, "server"),
			}
		end
	end
	local codegen_elapsed = (os.clock() - codegen_pin)

	local timings: Timings = {
		ast = ast_elapsed,
		hir = hir_elapsed,
		lir = lir_elapsed,
		codegen = codegen_elapsed,
		total = (ast_elapsed + hir_elapsed + lir_elapsed + codegen_elapsed),
	}

	return result.ok({
		lir = files_lir,
		hir = files_hir,
		files = files,
		timings = timings,
		targets = targets,
	})
end

return table.freeze({
	compile_from_path = compile_from_path,
})
