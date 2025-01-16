local hir = require("@compiler/hir")
local lir = require("@compiler/lir")
local types = require("@compiler/types")
local lexer = require("@compiler/lexer")
local parser = require("@compiler/parser")

local ast = require("@compiler/structures/ast")

local file = require("@util/file")
local panic = require("@util/panic")
local symbols = require("@util/symbols")
local diagnostics = require("@util/diagnostics")
local import_resolver = require("@util/import_resolver")

local colorful = require("@vendor/colorful")

type Ast = ast.Ast
type Symbols = ast.Symbols

type File = file.File
type FilesMap = types.FilesMap

local function file_to_ast(file: File): Ast
    local tokens = lexer.tokenize(file)
    return parser.parse(file, tokens)
end

--[=[
    Takes an entry file and builds a map of all files imported.
    @param `file` - The entry file from which to compile.
    @return `files` - A map of `file id` to AST
]=]
local function file_to_files_map(file: File): FilesMap
    --[[
        Recursively goes through all files in the import chain.
        Whenever an import is encountered it's resolved and parsed.
        Once parsed its symbols are added to the symbols of the importing scope.
        Note that already parsed files are cached using the files map.
    ]]

    local files: FilesMap = {}
    local process_file: (file: File) -> Symbols;

    local function stat_import(symbols: Symbols, stat: ast.StatImport)
        --- import `path`
        local path_expr = stat.path
        --- import ... as `name`
        local name_ident = stat.name

        local path = path_expr.value
    end

    local function node_block(symbols: Symbols, block: ast.Block)
        for _, statement in block.statements do
            if statement.kind == "scope" then
                node_block(symbols, statement.body)
            elseif statement.kind == "import" then
                stat_import(symbols, statement)
            end
        end
    end

    function process_file(file: File): Symbols
        local file_id = file.id
        local cached = files[file_id]
        if cached then
            return cached.symbols
        end

        local ast = file_to_ast(file)
        local symbols = ast.symbols

        -- resolve imports
        node_block(symbols, ast.body)

        -- cache ast for future use
        files[file_id] = ast

        return symbols
    end

    -- entry file
    process_file(file)

    return files
end

