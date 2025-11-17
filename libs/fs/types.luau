local file = require("@util/file")
local path = require("@util/path")
local result = require("@util/result")

type Path = path.Path
type File = file.File

export type FileType = "file" | "dir" | "link" | "fifo" | "socket" | "char" | "block" | "unknown"

export type IOError = {
	kind: "IOError",
	message: string,
}

export type Result<T = nil> = result.Result<T, IOError>

export type WriteOptions = {
	overwrite: boolean?,
}

export type MetadataPermissions = {
	read_only: boolean,
}

export type Metadata = {
	kind: FileType,
	created_at: number?,
	modified_at: number?,
	accessed_at: number?,
	permissions: MetadataPermissions,
}

export type API = {
	read_file: (path: Path) -> Result<File>,
	read_directory: (path: Path) -> Result<{ string }>,
	read_string_from_file: (path: Path) -> Result<string>,

	write_directory: (path: Path) -> Result,
	write_string_to_file: (path: Path, contents: string) -> Result,

	remove_file: (path: Path) -> Result,
	remove_directory: (path: Path) -> Result,

	exists: (path: Path) -> boolean,
	is_file: (path: Path) -> boolean,
	is_directory: (path: Path) -> boolean,

	type: (path: Path) -> Result<FileType>,
	metadata: (path: Path) -> Result<Metadata>,

	move: (from: Path, to: Path, options: WriteOptions?) -> Result,
	copy: (from: Path, to: Path, options: WriteOptions?) -> Result,
}

local function io_error(message: string): result.Error<IOError>
	return result.err({
		kind = "IOError" :: "IOError",
		message = message,
	})
end

return table.freeze({
	io_error = io_error,
})
