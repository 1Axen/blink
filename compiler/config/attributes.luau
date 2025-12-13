local compilation = require("@config/compilation")

export type Attributes = {
	export: true?,
	stable: true?,
	bitpack: true?,
	target: compilation.Target?,
	profile: compilation.Profile?,
}

return nil
