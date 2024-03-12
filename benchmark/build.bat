@echo off

setlocal
:PROMPT
SET "AREYOUSURE=N"
SET /P "AREYOUSURE=Download tools? (Y/[N])?"
IF /I %AREYOUSURE% NEQ Y GOTO COMPILE

echo Downloading dependencies...
rmdir /s /q ".\tools"
rmdir /s /q ".\packages"
mkdir ".\tools"
mkdir ".\packages"
lune run download
del /q ".\tools\*.zip"
del /q ".\packages\*.zip"

:COMPILE
echo Compiling definitions
if not exist "./src/shared/zap" mkdir "./src/shared/zap"
if not exist "./src/shared/blink" mkdir "./src/shared/blink"
"./tools/zap.exe" "./definitions/Definition.zap"
"./tools/blink.exe" "./definitions/Definition.blink"
endlocal

echo Building ROBLOX place
if not exist roblox mkdir roblox
rojo sourcemap default.project.json --output sourcemap.json --include-non-scripts
REM Update sourcemap used for luau-lsp
rojo sourcemap default.project.json --output ../sourcemap.json --include-non-scripts
darklua process src roblox
rojo build build.project.json --output "./Benchmark.rbxl"

setlocal
SET "OPENSTUDIO=N"
SET /P OPENSTUDIO=Open generated place? (Y/[N])?
if /I %OPENSTUDIO% NEQ Y GOTO END

lune run generate

:END
endlocal