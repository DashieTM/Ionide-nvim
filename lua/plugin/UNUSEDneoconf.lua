local neotree = tryRequire("neotree.nvim")

local neoconf = tryRequire("neoconf.plugins")
if neoconf == nil then
    ---@class SettingsPlugin
    ---@field name string
    ---@field setup fun()|nil
    ---@field on_update fun(event)|nil
    ---@field on_schema fun(schema: Schema)
    --construct a fake one to "register" the schema without it giving an error.
    ---@type  SettingsPlugin
    local fakeNeoConfRegisterOpts = {
        on_schema = function(schema) end,
    }

    neoconf = {
        ---comment
        ---@param plugin SettingsPlugin
        register = function(plugin) end,
    }
end
