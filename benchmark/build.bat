@echo off

setlocal
:PROMPT
SET /P AREYOUSURE=Download tools? (Y/[N])?
IF /I "%AREYOUSURE%" NEQ Y GOTO COMPILE

echo Downloading dependencies...
del /q ".\tools\*.*"
lune run download
del /q ".\tools\*.zip"

:COMPILE
echo Compiling definitions
"./tools/zap.exe" "./definitions/Definition.zap"
"./tools/blink.exe" "./definitions/Definition.blink"
endlocal

echo Building ROBLOX place
rojo sourcemap default.project.json --output sourcemap.json
darklua process src roblox
rojo build build.project.json --output "./Benchmark.rbxl"