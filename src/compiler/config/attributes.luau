local compilation = require("@config/compilation")

export type SharedAttributes = {
    profile: compilation.Profile?,
}

export type TypeAttributes = {
    stub: true?,
    stable: true?,
    bitpack: true?,
} & SharedAttributes

return nil