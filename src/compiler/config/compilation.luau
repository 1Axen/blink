local ast = require("@structures/ast")

local TARGETS = table.freeze({
    shared = true,
    client = true,
    server = true,
})

local PROFILES = table.freeze({
    dev = true,
    test = true,
    debug = true,
    release = true
})

export type Target = keyof<typeof(TARGETS)>
export type Profile = keyof<typeof(PROFILES)>
export type CompilerOptions = {
    --- Track how long each step took and report it to the standard out
    time: boolean,
    --- Controls whether the compiler will report internal information to the standard out
    verbose: boolean,
    profile: Profile,
}

--[=[
    Map of `file id` to `AST`.
    Since file id's are contigous the map also works as an array.
    Index 0 into the map *must* always be the entry file of the compilation.
]=] 
export type FilesMap = {[number]: ast.Ast}

return table.freeze({
    TARGETS = TARGETS,
    PROFILES = PROFILES
})