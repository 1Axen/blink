@echo Off
SET WINRAR="C:\Program Files\WinRAR\Rar.exe"

echo Clearing release folder
rmdir /s/q "../Blink"
mkdir "../Blink"

echo Bundling source code
darklua process ../src/init.luau ./Bundled.luau

echo Building standalone executable
lune build ./Bundled.luau
ren "./Bundled.exe" "blink.exe"
move "./blink.exe" "../release/"

echo Compiling bytecode
lune run compile.luau

echo Cloning init file
echo f | xcopy "./init.luau" "../Blink/init.luau" /f /v /s

echo Zipping files
%WINRAR% a "../release/bytecode.rar" "../Blink/*"

rmdir /s/q "../Blink" 

pause