@echo Off

mkdir "./bundle"
copy ".\src\Error.rbxmx" ".\bundle\Error.rbxmx"
copy ".\src\Widget.rbxmx" ".\bundle\Widget.rbxmx"
copy "..\build\.darklua.json" ".\.darklua.json"

darklua process "./src/init.server.luau" "./bundle/init.server.lua"
rojo build --plugin "Blink.rbxmx"

cd ..
rojo sourcemap --output sourcemap.json --include-non-scripts
cd plugin