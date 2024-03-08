local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local AUTH_TOKEN;
local PATH_TO_7ZIP = "C:\\Program Files\\7-Zip\\7z.exe"
local PATH_TO_TOOLS = "./tools/"
local PATH_TO_PACKAGES = "./packages/"

local Tools = {
    zap = "https://api.github.com/repos/red-blox/zap/releases/latest",
    blink = "https://api.github.com/repos/1Axen/blink/releases/latest",
}

local Packages: {[string]: {GitHub: string, Wally: string}} = {
    warp = {
        GitHub = "https://api.github.com/repos/imezx/Warp/releases", 
        Wally = "https://api.wally.run/v1/package-contents/imezx/warp/"
    },

    bytenet = {
        GitHub = "https://api.github.com/repos/ffrostflame/ByteNet/releases", 
        Wally = "https://api.wally.run/v1/package-contents/ffrostflame/bytenet/"
    }
}

local Versions = {}

if fs.isFile("config.json") then
    local Configuration = net.jsonDecode(fs.readFile("config.json"))
    AUTH_TOKEN = Configuration["github-token"]
    print(`Using github token to do API requests!`)
end

local function Curl(URL: string, Output: string, Headers: {string}?): process.SpawnResult
    local Arguments = {}

    if AUTH_TOKEN then
        table.insert(Arguments, "--header")
        table.insert(Arguments, `Authorization: Bearer {AUTH_TOKEN}`)
    end

    if Headers then
        for Index, Header in Headers do
            table.insert(Arguments, "--header")
            table.insert(Arguments, Header)
        end
    end

    table.insert(Arguments, "--location")
    table.insert(Arguments, URL)

    table.insert(Arguments, "--output")
    table.insert(Arguments, Output)

    return process.spawn("curl", Arguments)
end

local function Request(Fetch: net.FetchParams): net.FetchResponse
    if AUTH_TOKEN then
        Fetch.headers = Fetch.headers or {}
        (Fetch.headers :: any).Authorization = `Bearer {AUTH_TOKEN}`
    end
    
    local Response = net.request(Fetch)
    local Ratelimit = Response.headers["x-ratelimit-remaining"]

    if tonumber(Ratelimit) == 0 then
        error(`API rate limit exceeded, retry again in {Response.headers["x-ratelimit-reset"] - os.time()} seconds.`)
    end

    assert(Response.ok, Response.statusMessage)
    return Response
end

for Name, Url in Tools do
    local Response = Request({
        url = Url,
        method = "GET"
    })

    local Release = net.jsonDecode(Response.body)
    local DownloadUrl: string

    for Index, Asset in Release.assets do
        if not string.find(Asset.name, "windows-x86_64", 1, true) then
            continue
        end

        DownloadUrl = Asset.browser_download_url
    end

    assert(DownloadUrl, `Unable to find download URL for {Name}`)

    local CurlResult = Curl(DownloadUrl, `{PATH_TO_TOOLS}{Name}.zip`)
    assert(CurlResult.ok, `Encountered an exception while downloading files for {Name}, {CurlResult.code}`)

    local UnzipResult = process.spawn(`{PATH_TO_7ZIP}`, {"e", `{PATH_TO_TOOLS}{Name}.zip`, "-y", `-o{PATH_TO_TOOLS}`})
    assert(UnzipResult.ok, `Encountered an exception while unzipping downloads for {Name}, {UnzipResult.stderr}`)

    Versions[Name] = Release.tag_name
    print("Downloaded", Name, Release.tag_name)
end

for Name, Urls in Packages do
    local Response = Request({
        url = Urls.GitHub,
        method = "GET"
    })

    local Releases = net.jsonDecode(Response.body)
    table.sort(Releases, function(a, b)
        return a.id > b.id
    end)

    local Release = Releases[1]
    local Version = Release.tag_name
    local PackageVersion = Version

    local ZipPath = `{PATH_TO_PACKAGES}{Name}_ZIP`
    local FinalPath = `{PATH_TO_PACKAGES}{Name}`

    if string.sub(Version, 1, 1) == "v" then
        PackageVersion = string.sub(Version, 2)
    end

    local DownloadUrl = `{Urls.Wally}{PackageVersion}`
    local CurlResult = Curl(DownloadUrl, `{ZipPath}.zip`, {"Wally-Version: 0.3.2"})
    assert(CurlResult.ok, `Encountered an exception while downloading files for {Name}, {CurlResult.stderr}`)

    if not fs.isDir(ZipPath) then
        fs.writeDir(ZipPath)
    end

    local UnzipResult = process.spawn(`{PATH_TO_7ZIP}`, {"x", `{ZipPath}.zip`, "-y", `-o{ZipPath}`})
    assert(UnzipResult.ok, `Encountered an exception while unzipping downloads for {Name}, {UnzipResult.stderr}`)

    fs.move(`{ZipPath}/src`, FinalPath)
    fs.removeDir(ZipPath)

    Versions[Name] = Version
    print("Downloaded", Name, Version)
end

fs.writeFile("./tools/versions.json", net.jsonEncode(Versions))