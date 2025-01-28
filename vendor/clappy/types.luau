export type TypeObject<T> = {
	name: string,
	validator: (value: string) -> boolean,
	convert: (value: string) -> T,
}

export type Opt<T> = {
	description: string,
	type: TypeObject<T>,
}

export type Parameter<T> = {
	position: number,
	description: string,
	type: TypeObject<T>,
}

export type DefineParameter = <T>(thing: Parameter<T>) -> T
export type DefineOpt = <T>(thing: Opt<T>) -> T?
export type DefineCommand = <T, K>(
	config: {
		name: string,
		description: string,
		parameters: T,
		opts: K,
	},
	runner: (parameters: T, opts: K) -> ()
) -> CommandInfo

export type CommandInfo = {
	name: string,
	description: string,

	runner: (parameters: any, opts: any) -> (),

	parameters: {
		[number]: {
			name: string,
			description: string,
			type: TypeObject<unknown>,
		},
	},
	opts: {
		[string]: {
			name: string,
			description: string,
			type: TypeObject<unknown>,
		},
	},
}

return nil