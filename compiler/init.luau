local ast = require("@self/ast/types")
local codegen = require("@self/codegen")
local codes = require("@self/config/codes")
local compilation = require("@self/config/compilation")
local diagnostics = require("@util/diagnostics")
local file = require("@util/file")
local fs = require("@util/fs")
local hir = require("@compiler/hir")
local import_resolver = require("@util/import_resolver")
local lexer = require("@compiler/lexer")
local lir = require("@compiler/lir")
local options = require("@compiler/config/options")
local parser = require("@compiler/parser")
local path = require("@util/path")
local result = require("@util/result")
local strong_exhaustive_match = require("@util/strong_exhaustive_match")
local style = require("@util/style")
local typeforge = require("@util/typeforge")

local md5 = require("@vendor/md5")

type Ast = ast.Ast

type Path = path.Path
type File = file.File

type Files = compilation.Files
type Target = compilation.Target
type Profile = compilation.Profile

type Context = {
	read directory: Path,
	read imports: { import_resolver.Import },
}

export type Targets = typeforge.StringUnionToStruct<Target, {
	path: Path,
	contents: string,
}?>

type FileOptions = options.FileOptions
export type CompileOptions = {
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
	files: Files,
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
	return diagnostics
		.error(codes.analysis.InvalidImport)
		:with_message(`Unknown import: "{path.to_string(err.path)}"`)
		:with_label(
			diagnostics
				.label(expr.span)
				:with_style(style.color.red)
				:with_message("Unable to locate the imported file, make sure the path is correct.")
		)
		:error()
end

local function report_unknown_alias(err: import_resolver.UnknownAlias, expr: ast.ExprString): never
	return diagnostics
		.error(codes.analysis.InvalidImport)
		:with_message(`Unknown alias: "@{err.alias}"`)
		:with_label(
			diagnostics
				.label(expr.span)
				:with_style(style.color.red)
				:with_message("The alias wasn't found in any luaurc files, make sure it's correct.")
		)
		:error()
end

local function report_import_io_error(err: fs.IOError, expr: ast.ExprString): never
	return diagnostics
		.error(codes.analysis.InvalidImport)
		:with_message(`Encountered an IO error while importing "{expr.value}": {err.message}.`)
		:with_label(
			diagnostics
				.label(expr.span)
				:with_style(style.color.red)
				:with_message("Make sure blink has permission to read the import's file contents.")
		)
		:error()
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
local function file_to_files_map(entry_file: File, entry_path: Path): Files
	--[[
        Recursively goes through all files in the import chain.
        Whenever an import is encountered it's resolved and parsed.
        Once parsed its symbols are added to the symbols of the importing scope.
        Note that already parsed files are cached using the files map.
    ]]

	local ast_map: { [number]: Ast } = {}
	local sorted_ids: { number } = {}
	local imports_map: { [ast.StatImport]: number } = {}
	local ref_count_map: { [number]: number? } = {}

	local function stat_import(ctx: Context, stat: ast.StatImport): never?
		local path_expr = stat.path
		local import_path = path.from_string(path_expr.value)
		local resolve_result = import_resolver.resolve(ctx.directory, import_path)
		if resolve_result.ok == false then
			local err = resolve_result.error
			if err.kind == "IOError" then
				return report_import_io_error(err, path_expr)
			elseif err.kind == "UnknownAlias" then
				return report_unknown_alias(err, path_expr)
			elseif err.kind == "UnknownImport" then
				return report_unknown_import(err, path_expr)
			end

			return strong_exhaustive_match(err.kind)
		end

		local import = resolve_result.value
		imports_map[stat] = import.file.id
		table.insert(ctx.imports, import)

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

	local function process_file(file: File, file_path: Path, ref_count: number)
		local file_id = file.id
		local prev_ref_count = ref_count_map[file_id]
		if prev_ref_count then
			ref_count_map[file_id] = math.max(prev_ref_count, ref_count)
			return
		end

		-- parse file and store
		local ast = file_to_ast(file)
		ast_map[file_id] = ast
		ref_count_map[file_id] = ref_count
		table.insert(sorted_ids, file_id)

		-- resolve imports
		local context: Context = {
			imports = {},
			directory = path.strip_file_name(file_path),
		}

		node_block(context, ast.body)

		-- process imports
		for _, import in context.imports do
			process_file(import.file, import.path, ref_count + 1)
		end
	end

	-- entry file
	process_file(entry_file, entry_path, 0)

	-- sort ids
	table.sort(sorted_ids, function(a: number, b: number): boolean
		return assert(ref_count_map[a]) > assert(ref_count_map[b])
	end)

	return table.freeze({
		ast_map = ast_map,
		sorted_ids = sorted_ids,
		imports_map = imports_map,
	})
end

--[=[
    Takes a path to a file to compile.
    @param `file_path` - An absolute path to the file which to compile.
]=]
local function compile_from_path(entry_path: Path, compile_options: CompileOptions): CompilationResult
	local read_result = fs.read_file(entry_path)
	if read_result.ok == false then
		return read_result
	end

	local ast_pin = os.clock()
	local entry_file = read_result.value
	local files = file_to_files_map(entry_file, entry_path)
	local ast_elapsed = (os.clock() - ast_pin)

	local hir_pin = os.clock()
	local files_hir = hir.from_files(files)
	local hir_elapsed = (os.clock() - hir_pin)

	local lir_pin = os.clock()
	local files_lir = lir.from_hir(files_hir)
	local lir_elapsed = (os.clock() - lir_pin)

	local codegen_pin = os.clock()
	local targets: Targets = {}
	do
		local entry_options = hir.file_options(files_hir, entry_file)
		local codegen_props: codegen.Props = {
			lir = files_lir,
			hir = files_hir,
			hash = md5(tostring(os.clock())),
			profile = compile_options.profile,
			entry_options = entry_options,
		}

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

local function compile_contents(
	contents: string,
	compile_options: CompileOptions
): {
	read types: string,
	read client: string,
	read server: string,
}
	local mock_file = file.from_source("input.blink", contents)
	local files: Files = {
		ast_map = { [mock_file.id] = file_to_ast(mock_file) },
		sorted_ids = { mock_file.id },
		imports_map = {},
	}

	local file_hir = hir.from_files(files)
	local file_lir = lir.from_hir(file_hir)

	local entry_options = hir.file_options(file_hir, mock_file)
	local codegen_props: codegen.Props = {
		hir = file_hir,
		lir = file_lir,
		hash = md5(tostring(os.clock())),
		profile = compile_options.profile,
		entry_options = entry_options,
	}

	return table.freeze({
		types = codegen.from_lir(codegen_props, "types"),
		client = codegen.from_lir(codegen_props, "client"),
		server = codegen.from_lir(codegen_props, "server"),
	})
end

return table.freeze({
	compile_contents = compile_contents,
	compile_from_path = compile_from_path,
})
