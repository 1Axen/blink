--!strict

---- Imports ----

local fs = require("@lune/fs")
local task = require("@lune/task")
local stdio = require("@lune/stdio")
local dateTime = require("@lune/datetime")

local Compile = require("./Compile")
local PathParser = require("../../Modules/Path")
local GetDefinitionFilePath = require("./GetDefinitionFilePath")

---- Settings ----

type DateTime = dateTime.DateTime

local IMPORT_PATTERN = `import "([%w%/%.-_]+)"`
local WATCH_OPTIONS: Compile.CompileOptions = {
    Debug = false,
    Silent = true,
    YesToEverything = true,
    OutputAbstractSyntaxTree = false
}

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

local function Color(Color: stdio.Color, Text: string): string
    return `{stdio.color(Color)}{Text}{stdio.color("reset")}`
end

local function BuildImportsArray(Entry: string, PreviousArray: {string}?): {string}
    local Array = PreviousArray or {}
    table.insert(Array, Entry)

    local Source = fs.readFile(Entry)
    local Directory = PathParser.Directory(Entry)
    local Iterator = string.gmatch(Source, IMPORT_PATTERN)

    while (true) do
        local Path = Iterator()
        if not Path then
            break
        end

        Path = `{Directory}{Path}`
        Path = GetDefinitionFilePath(Path)

        if not fs.isFile(Path) then
            error(`No file to import at "{Path}"`)
        end

        --> Prevent repeats
        if table.find(Array, Path) then
            continue
        end

        BuildImportsArray(Path, Array)
    end

    return Array
end

---- Public Functions ----

function Utility.Watch(Path: string)
    local FilePath = GetDefinitionFilePath(Path)

    local Imports: {string};
    local ShouldUpdateStatus = true

    local function Recompile()
        --> Resolve imports
        local OldImports = Imports and #Imports or 0
        Imports = BuildImportsArray(FilePath)

        if OldImports ~= #Imports then
            ShouldUpdateStatus = true
        end

        --> Compile
        Compile.Compile(Path, WATCH_OPTIONS)

        --> Status
        if ShouldUpdateStatus then
            ShouldUpdateStatus = false
            print(`Blink is watching for changes:\n\tEntry: {Color("yellow", FilePath)}\n\tImports: {Color("yellow", tostring(#Imports - 1))}`)
        end

        return true
    end

    --> Initial compilation
    local InitialSuccess, Why = pcall(Recompile)
    if not InitialSuccess then
        warn(`There was an error while trying to start the watcher thread:\n{Why}`)
        return
    end

    --> Watch loop
    local LastModification: {[string]: number} = {}

    while true do
        for _, File in Imports do
            local Metadata = fs.metadata(File)

            --> Make sure file still exists
            if not Metadata.exists then
                continue
            end

            local LastModified = LastModification[File]
            if not LastModified then
                LastModification[File] = Metadata.modifiedAt or 0
                continue
            end

            if Metadata.modifiedAt ~= LastModified then
                local Success, Error = pcall(Recompile)
                if not Success then
                    warn(Error)
                end

                --> Prevent spam errors
                table.clear(LastModification)
                break
            end
        end
        
        task.wait(1)
    end
end

---- Initialization ----

---- Connections ----

return Utility