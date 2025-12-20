local string_builder = require("@util/string_builder")

type StringBuilder = string_builder.StringBuilder

export type Datatype = {
	read append: (builder: StringBuilder) -> (),
	read generate: (seed: number) -> any,
}

return nil
