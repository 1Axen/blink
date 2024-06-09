@echo Off
SET ZIP="C:\Program Files\7-Zip\7z.exe"
SET /p VERSION=What version is being built?:

echo Clearing release folder
del /s /q "../release"
rmdir /s/q "../Blink"
mkdir "../release"
mkdir "../Blink"

lune run version.luau %VERSION%

echo Bundling source code
darklua process ../src/CLI/init.luau ./Bundled.luau

echo Building standalone executable

lune build ./Bundled.luau --output blink --target windows-x86_64
%ZIP% a "../release/blink-%VERSION%-windows-x86_64.zip" "blink.*" > nul
del "./blink.*"

lune build ./Bundled.luau --output blink --target macos-x86_64
%ZIP% a "../release/blink-%VERSION%-macos-x86_64.zip" "blink" > nul
del "./blink.*"

lune build ./Bundled.luau --output blink --target linux-x86_64
%ZIP% a "../release/blink-%VERSION%-linux-x86_64.zip" "blink" > nul
del "./blink.*"

lune build ./Bundled.luau --output blink --target macos-aarch64
%ZIP% a "../release/blink-%VERSION%-macos-aarch64.zip" "blink" > nul
del "./blink.*"

lune build ./Bundled.luau --output blink --target linux-aarch64
%ZIP% a "../release/blink-%VERSION%-linux-aarch64.zip" "blink" > nul
del "./blink.*"

echo Compiling bytecode
lune run compile.luau

echo Zipping files
%ZIP% a "../release/bytecode.zip" "Bytecode.txt" > nul
%ZIP% a "../release/bytecode.zip" "init.luau" > nul

echo Packaging plugin
cd ../plugin
copy "..\build\.darklua.json" ".\.darklua.json"
darklua process "./src/init.server.luau" "./bundle/init.server.lua"
rojo build bundle.project.json --output "../release/Plugin-%VERSION%.rbxmx"

cd ../build

del "./Bytecode.txt"
rmdir /s/q "../Blink" 

pause