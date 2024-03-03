local net = require("@lune/net")
local process = require("@lune/process")

local PATH_TO_7ZIP = "C:\\Program Files\\7-Zip\\7z.exe"

local Tools = {
    zap = "https://api.github.com/repos/red-blox/zap/releases/latest",
    blink = "https://api.github.com/repos/1Axen/blink/releases/latest",
}

for Name, Url in Tools do
    local Response = net.request({
        url = Url,
        method = "GET",
    })

    assert(Response.ok, Response.statusMessage)
    local Json = net.jsonDecode(Response.body)
    local DownloadUrl: string
    for Index, Asset in Json.assets do
        if not string.find(Asset.name, "windows-x86_64", 1, true) then
            continue
        end

        DownloadUrl = Asset.browser_download_url
    end

    assert(DownloadUrl, `Unable to find download URL for {Name}`)

    local CurlResult = process.spawn("curl", {"--location", DownloadUrl, "--output", `./tools/{Name}.zip`})
    assert(CurlResult.ok, `Encountered an exception while downloading files for {Name}, {CurlResult.code}`)

    local UnzipResult = process.spawn(`{PATH_TO_7ZIP}`, {"e", `./tools/{Name}.zip`, "-y", "-o./tools"})
    assert(UnzipResult.ok, `Encountered an exception while unzipping downloads for {Name}, {UnzipResult.stderr}`)

    print("Downloaded", Name)
end
