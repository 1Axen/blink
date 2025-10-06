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
local symbols = require("@compiler/symbols")

local fmt_hir = require("@self/hir/format")
local fmt_lir = require("@self/lir/format")
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

export type Targets = {
	[Target]: string?,
}

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

export type Result = {
	hir: hir.Hir,
	lir: lir.Lir,
	files: FilesMap,
	timings: Timings,
	targets: Targets,
}

local function report_unknown_require(expr: ast.ExprString): never
	return diagnostics.report
		.create("Error")
		.with_code(codes.analysis.InvalidImport)
		.with_message(`Unknown import: "{expr.value}"`)
		.with_label(
			diagnostics.label
				.create(expr.span)
				.with_color(diagnostics.style.color.red)
				.with_message("Unknown import, make sure the path is correct.")
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

		if import_result.error then
			if import_result.error == "IOError" then
				return panic(`IO error while attempting to import "{path_expr.value}"`)
			end

			return report_unknown_require(path_expr)
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
local function compile_from_path(entry_path: Path, compiler_options: Options): Result?
	local fs_result = fs.read_file(entry_path)
	if fs_result.error then
		return nil
	end

	local ast_pin = os.clock()
	local files = file_to_files_map(fs_result.value, entry_path)
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
		-- local entry_options = files_hir.options[0]
		-- if entry_options.shared_output then
		-- 	targets.shared = codegen.from_lir(files_lir, "shared")
		-- end
		-- if entry_options.client_output then
		-- 	targets.client = codegen.from_lir(files_lir, "client")
		-- end
		-- if entry_options.server_output then
		-- 	targets.server = codegen.from_lir(files_lir, "server")
		-- end

		local props: codegen.Props = {
			lir = files_lir,
			hir = files_hir,
			hash = md5(tostring(os.clock())),
			profile = compiler_options.profile,
		}

		targets.shared = codegen.from_lir(props, "shared")
		targets.server = codegen.from_lir(props, "server")
		targets.client = codegen.from_lir(props, "client")
	end
	local codegen_elapsed = (os.clock() - codegen_pin)

	local timings: Timings = {
		ast = ast_elapsed,
		hir = hir_elapsed,
		lir = lir_elapsed,
		codegen = codegen_elapsed,
		total = (ast_elapsed + hir_elapsed + lir_elapsed + codegen_elapsed),
	}

	return {
		lir = files_lir,
		hir = files_hir,
		files = files,
		timings = timings,
		targets = targets,
	}
end

local function compile_from_snippet(snippet: string, options: Options): boolean
	return true
end

return table.freeze({
	compile_from_path = compile_from_path,
	compile_from_snippet = compile_from_snippet,
})
