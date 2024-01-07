@echo Off
SET WINRAR="C:\Program Files\WinRAR\Rar.exe"

echo Clearing release folder
rmdir /s/q "../Blink"
mkdir "../Blink"

echo Bundling source code
darklua process ../src/init.luau ./Bundled.luau

echo Compiling bytecode
lune compile.luau

echo Cloning init file
echo f | xcopy "./init.luau" "../Blink/init.luau" /f /v /s

echo Zipping files
%WINRAR% a "../release.rar" "../Blink/*"

pause