--!strict
--> Temporary file used for tracking performance with every change

local fs = require("@std/fs")
local time = require("@lute/time")

local file = require("@util/file")

local hir = require("@compiler/hir")
local lexer = require("@compiler/lexer")
local lir = require("@compiler/lir")
local parser = require("@compiler/parser")

local OUT_PATH = "./out/performance.txt"

if fs.exists("./out") == false then
	fs.createdirectory("./out")
end

local function fs_append(path: string, text: string)
	local contents = fs.exists(path) and fs.readfiletostring(path) or ""
	fs.writestringtofile(path, contents .. text)
end

local function format_seconds(seconds: number): string
	local suffix = "seconds"
	if seconds < 1E-6 then
		seconds *= 1E+9
		suffix = "ns"
	elseif seconds < 0.001 then
		seconds *= 1E+6
		suffix = "μs"
	elseif seconds < 1 then
		seconds *= 1000
		suffix = "ms"
	end

	return string.format("%.2f %s", seconds, suffix)
end

local function benchmark_closure(name: string, closure: () -> ()): number
	local time_sum = 0
	for _ = 1, 1_000 do
		local start = os.clock()

		closure()

		local elapsed = (os.clock() - start)
		time_sum += elapsed
	end

	local average_time = time_sum / 1_000
	local text_result = `{time.now()} - {name} - {format_seconds(average_time)}`

	print(text_result)
	fs_append(OUT_PATH, `\n{text_result}`)

	return average_time
end

local small_file = file.from_source("small.blink", fs.readfiletostring("./blink/small.blink"))
local large_file = file.from_source("large.blink", fs.readfiletostring("./blink/large.blink"))
local bench_file = file.from_source("bench.blink", fs.readfiletostring("./blink/bench.blink"))

local small_tokens = lexer.tokenize(small_file)
local large_tokens = lexer.tokenize(large_file)
local bench_tokens = lexer.tokenize(bench_file)

local large_ast = parser.parse(large_file, large_tokens)
local bench_ast = parser.parse(bench_file, bench_tokens)

local bench_files = { [bench_file.id] = bench_ast }
local large_files = { [large_file.id] = large_ast }

local large_hir = hir.from_files(bench_files)
local bench_hir = hir.from_files(large_files)

fs_append(OUT_PATH, `\n{string.rep("-", 16)}`)

benchmark_closure("lexer: small.blink", function()
	lexer.tokenize(small_file)
end)

benchmark_closure("lexer: large.blink", function()
	lexer.tokenize(large_file)
end)

benchmark_closure("lexer: bench.blink", function()
	lexer.tokenize(bench_file)
end)

benchmark_closure("parser: small.blink", function()
	parser.parse(small_file, small_tokens)
end)

benchmark_closure("parser: large.blink", function()
	parser.parse(large_file, large_tokens)
end)

benchmark_closure("parser: bench.blink", function()
	lexer.tokenize(bench_file)
end)

benchmark_closure("hir: bench.blink", function()
	hir.from_files(bench_files)
end)

benchmark_closure("hir: large.blink", function()
	hir.from_files(large_files)
end)

benchmark_closure("lir: bench.blink", function()
	lir.from_hir(bench_hir)
end)

benchmark_closure("lir: large.blink", function()
	lir.from_hir(large_hir)
end)

benchmark_closure("codegen: bench.blink", function() end)

benchmark_closure("codegen: large.blink", function() end)

benchmark_closure("full: bench.blink", function()
	local tokens = lexer.tokenize(bench_file)
	local ast = parser.parse(bench_file, tokens)
	local hir = hir.from_files({ [bench_file.id] = ast })
	local _lir = lir.from_hir(hir)
end)

benchmark_closure("full: large.blink", function()
	local tokens = lexer.tokenize(large_file)
	local ast = parser.parse(large_file, tokens)
	local hir = hir.from_files({ [large_file.id] = ast })
	local _lir = lir.from_hir(hir)
end)
