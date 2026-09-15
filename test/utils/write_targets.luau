local fs = require("@util/fs")
local path = require("@util/path")

type Path = path.Path

export type Paths = {
	read types: Path,
	read client: Path,
	read server: Path,
}

export type Targets = {
	read types: string,
	read client: string,
	read server: string,
}

local TEMP_PATH = path.from_string("./temp")

const function write_targets(prefix: string, targets: Targets)
	const paths = {}
	for target, contents in targets :: { [string]: string } do
		const target_path = path.append_file_name(TEMP_PATH, `{prefix}-{target}`, "luau")
		const write_result = fs.write_string_to_file(target_path, contents)
		if write_result.ok then
			paths[target] = target_path
			continue
		end

		error(`failed to write "{path.to_string(target_path)}", {write_result.error.message}`)
	end

	return table.freeze(paths) :: Paths
end

return write_targets
