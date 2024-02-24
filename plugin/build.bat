@echo Off

copy "..\build\.darklua.json" ".\.darklua.json"
darklua process "./src/init.luau" "./bundle/init.server.lua"
rojo build --output "%LocalAppData%\Roblox\Plugins\Blink.rbxmx"