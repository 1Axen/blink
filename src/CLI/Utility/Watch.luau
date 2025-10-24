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
    Compact = false,
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

    _G.WATCH_THREAD = true

    local function Traverse()
        --> Resolve imports
        local OldImports = Imports and #Imports or 0
        Imports = BuildImportsArray(FilePath)

        if OldImports ~= #Imports then
            print(`Blink is watching for changes:\n\tEntry: {Color("yellow", FilePath)}\n\tImports: {Color("yellow", tostring(#Imports - 1))}`)
        end
        
        return true
    end

    local function Recompile()
        Traverse()
        Compile.Compile(Path, WATCH_OPTIONS)
    end

    --> Initial traversal
    local InitialSuccess, Why = pcall(Traverse)
    if not InitialSuccess then
        warn(`There was an error while trying to start the watcher thread:\n{Why}`)
        return
    end

    --> Watch loop
    local Timestamps: {[string]: number} = {}

    while true do
        local FileChanged = false
        for _, File in Imports do
            local Metadata = fs.metadata(File)

            --> Make sure file still exists
            if not Metadata.exists then
                continue
            end

            local ModifiedAt = Metadata.modifiedAt and Metadata.modifiedAt.unixTimestampMillis or 0
            local LastModifiedA = Timestamps[File]
            Timestamps[File] = ModifiedAt

            if ModifiedAt ~= LastModifiedA then
                FileChanged = true
            end
        end

        if FileChanged then
            pcall(Recompile)
        end
        
        task.wait(1)
    end
end

---- Initialization ----

---- Connections ----

return Utility