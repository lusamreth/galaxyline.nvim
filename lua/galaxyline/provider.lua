local function load_providers()
    return {
        conditions = require("galaxyline.condtions"),
        vcs = require("galaxyline.providers.vcs"),
        fileinfo = require("galaxyline.providers.fileinfo"),
        buffer = require("galaxyline.providers.buffer"),
        search = require("galaxyline.providers.search"),
        extension = require("galaxyline.providers.extensions"),
        whitespace = require("galaxyline.providers.whitespace"),
        lspclient = require("galaxyline.providers.lsp")
    }
end

return {
    load_providers = load_providers
}
