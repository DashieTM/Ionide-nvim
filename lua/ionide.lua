local M = {}

---@param config
function M.setup(config)
    local init = require("plugin")
    init.config.MergedConfig = vim.tbl_deep_extend("force", init.config.DefaultLspConfig, init.config.PassedInConfig)
    -- TODO fsi
    --M.InitializeDefaultFsiKeymapSettings()
    local manager = init.CreateManager(init.config.DefaultLspConfig)
    --init.Initialize()
    --init.UpdateServerConfig(init.config.MergedConfig.settings.FSharp)
end

function M.show_config()
    vim.notify("Config is:\n" .. vim.inspect(init.config.MergedConfig))
end

return M
