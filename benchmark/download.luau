local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local PATH_TO_7ZIP = "C:\\Program Files\\7-Zip\\7z.exe"
local PATH_TO_TOOLS = "./tools/"
local PATH_TO_PACKAGES = "./packages/"

local Tools = {
    zap = "https://api.github.com/repos/red-blox/zap/releases/latest",
    blink = "https://api.github.com/repos/1Axen/blink/releases/latest",
}

local Packages: {[string]: {GitHub: string, Wally: string}} = {
    bytenet = {
        GitHub = "https://api.github.com/repos/ffrostflame/ByteNet/releases", 
        Wally = "https://api.wally.run/v1/package-contents/ffrostflame/bytenet/"
    }
}

local Versions = {}

local function Request(Fetch: net.FetchParams): net.FetchResponse
    Fetch.headers = Fetch.headers or {}
    

    local Response = net.request(Fetch)
    local Ratelimit = Response.headers["x-ratelimit-remaining"]

    if tonumber(Ratelimit) == 0 then
        error(`API rate limit exceeded, retry again in {Response.headers["x-ratelimit-reset"] - os.time()} seconds.`)
    end

    assert(Response.ok, Response.statusMessage)
    return Response
end

--[[for Name, Url in Tools do
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

    local CurlResult = process.spawn("curl", {"--location", DownloadUrl, "--output", `{PATH_TO_TOOLS}{Name}.zip`})
    assert(CurlResult.ok, `Encountered an exception while downloading files for {Name}, {CurlResult.code}`)

    local UnzipResult = process.spawn(`{PATH_TO_7ZIP}`, {"e", `{PATH_TO_TOOLS}{Name}.zip`, "-y", `-o{PATH_TO_TOOLS}`})
    assert(UnzipResult.ok, `Encountered an exception while unzipping downloads for {Name}, {UnzipResult.stderr}`)

    Versions[Name] = Release.tag_name
    print("Downloaded", Name, Release.tag_name)
end]]

for Name, Urls in Packages do
    --[[local Response = Request({
        url = Urls.GitHub,
        method = "GET"
    })

    local Releases = net.jsonDecode(Response.body)
    table.sort(Releases, function(a, b)
        return a.id > b.id
    end)]]

    --local Release = Releases[1]
    local Path = `{PATH_TO_PACKAGES}{Name}`
    local Version = "v0.4.0"--Release.tag_name
    local DownloadUrl = `{Urls.Wally}{string.sub(Version, 2)}`

    local CurlResult = process.spawn("curl", {"--header", "Wally-Version: 0.3.2", "--location", DownloadUrl, "--output", `{Path}.zip`})
    assert(CurlResult.ok, `Encountered an exception while downloading files for {Name}, {CurlResult.code}`)

    if not fs.isDir(Path) then
        fs.writeDir(Path)
    end

    local UnzipResult = process.spawn(`{PATH_TO_7ZIP}`, {"e", `{Path}.zip`, "-y", `-o{Path}`})
    assert(UnzipResult.ok, `Encountered an exception while unzipping downloads for {Name}, {UnzipResult.stderr}`)

    Versions[Name] = Version
    print("Downloaded", Name, Version)
end

fs.writeFile("./tools/versions.json", net.jsonEncode(Versions))