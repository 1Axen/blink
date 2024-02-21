@echo Off
SET ZIP="C:\Program Files\7-Zip\7z.exe"
SET VERSION="0.6.1"

echo Clearing release folder
rmdir /s/q "../Blink"
mkdir "../Blink"

lune run version.luau %VERSION%

echo Bundling source code
darklua process ../src/init.luau ./Bundled.luau

echo Building standalone executable
lune build ./Bundled.luau
ren "./Bundled.exe" "blink.exe"

echo Compiling bytecode
lune run compile.luau

echo Zipping files
%ZIP% a "../release/blink-%VERSION%-windows-x86_64.zip" "blink.exe" > nul
%ZIP% a "../release/bytecode.zip" "Bytecode.txt" > nul
%ZIP% a "../release/bytecode.zip" "init.luau" > nul

del "./*.exe"
del "./Bytecode.txt"
rmdir /s/q "../Blink" 

pause