local path = require("@util/path")
local file = require("@util/file")
local result = require("@util/result")

type Path = path.Path
type File = file.File
type Result<T, E> = result.Result<T, E>

export type IOError = "IOError"

export type WriteOptions = {
    overwrite: boolean?
}

export type MetadataPermissions = {
    read_only: boolean,
}

export type Metadata = {exists: false} | {
    exists: true,
    kind: "file" | "dir" | "symlink",
    created_at: number?,
    modified_at: number?,
    accessed_at: number?,
    permissions: MetadataPermissions
}

export type API = {
    read_file: (target: Path) -> Result<File, IOError>,
    read_directory: (target: Path) -> Result<{string}, IOError>,

    write_file: (target: Path, file: File) -> Result<nil, IOError>,
    write_directory: (target: Path) -> Result<nil, IOError>,

    remove_file: (target: Path) -> Result<nil, IOError>,
    remove_directory: (target: Path) -> Result<nil, IOError>,
    
    is_file: (target: Path) -> Result<boolean, IOError>,
    is_directory: (target: Path) -> Result<boolean, IOError>,

    metadata: (target: Path) -> Result<Metadata, IOError>,

    move: (from: Path, to: Path, options: WriteOptions?) -> Result<nil, IOError>,
    copy: (from: Path, to: Path, options: WriteOptions?) -> Result<nil, IOError>,
}

return nil