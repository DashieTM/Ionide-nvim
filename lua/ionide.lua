local api = vim.api
local lsp = vim.lsp
local M = {}

M.util = require("plugin.util")
M.config = require("plugin.config")
M.handlers = require("plugin.handlers")
M.autocmds = require("plugin.autocmds")
M.manager = nil
M.get_root_dir = nil
M.Manager = nil

---@param config
function M.setup(config)
    M.config.MergedConfig = vim.tbl_deep_extend("force", M.config.DefaultLspConfig, M.config.PassedInConfig)
    -- TODO fsi
    --M.InitializeDefaultFsiKeymapSettings()
    local manager = M.CreateManager(M.config.DefaultLspConfig)
    --init.Initialize()
    --init.UpdateServerConfig(init.config.MergedConfig.settings.FSharp)
end

function M.show_config()
    vim.notify("Config is:\n" .. vim.inspect(M.config.MergedConfig))
end

---@generic F: fun()
---@param fn F
---@return F
function M.noautocmd(fn)
    return function(...)
        vim.o.eventignore = "all"
        local ok, ret = pcall(fn, ...)
        vim.o.eventignore = ""
        if not ok then
            error(ret)
        end
        return ret
    end
end

--- @generic F: function
--- @param fn F
--- @param ms? number
--- @return F
function M.throttle(fn, ms)
    ms = ms or 200
    local timer = assert(vim.loop.new_timer())
    local waiting = 0
    return function()
        if timer:is_active() then
            waiting = waiting + 1
            return
        end
        waiting = 0
        fn() -- first call, execute immediately
        timer:start(ms, 0, function()
            if waiting > 1 then
                vim.schedule(fn) -- only execute if there are calls waiting
            end
        end)
    end
end

--- @generic F: function
--- @param fn F
--- @param ms? number
--- @return F
function M.debounce(fn, ms)
    ms = ms or 50
    local timer = assert(vim.loop.new_timer())
    local waiting = 0
    return function()
        if timer:is_active() then
            waiting = waiting + 1
        else
            waiting = 0
            fn()
        end
        timer:start(ms, 0, function()
            if waiting then
                vim.schedule(fn) -- only execute if there are calls waiting
            end
        end)
    end
end

M.getIonideClientAttachedToCurrentBufferOrFirstInActiveClients = function()
    local bufnr = vim.api.nvim_get_current_buf()
    -- local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
    -- local projectRoot = vim.fs.normalize(M.GitFirstRootDir(bufname))
    local ionideClientsList = vim.lsp.get_clients({ name = "ionide" })
    if ionideClientsList then
        if #ionideClientsList > 1 then
            for _, client in ipairs(ionideClientsList) do
                if vim.list_contains(vim.tbl_keys(client.attached_buffers), bufnr) then
                    return client
                end
                -- local root = client.config.root_dir or ""
                -- if vim.fs.normalize(root) == projectRoot then
                --   return client
                -- end
            end
        else
            if ionideClientsList[1] then
                return ionideClientsList[1]
            end
            return nil
        end
    else
        return nil
    end
end

M.getIonideClientConfigRootDirOrCwd = function()
    local ionide = M.getIonideClientAttachedToCurrentBufferOrFirstInActiveClients()
    if ionide then
        return vim.fs.normalize(ionide.config.root_dir or "")
    else
        return vim.fs.normalize(vim.fn.getcwd())
    end
end

M.projectFolders = {}

---@type table<string,ProjectInfo>
M.Projects = {}

---Resets the project folders and Projects tables to empty
function M.ClearLocalIonideProjectsCollection()
    M.Projects = {}
    M.projectFolders = {}
end

---@param content any
---@returns PlainNotification
function M.PlainNotification(content)
    -- return vim.cmd("return 'Content': a:" .. content .. " }")
    return { Content = content }
end

---Creates an lsp.Position from a line and character number
---@param line integer
---@param character integer
---@return lsp.Position
function M.Position(line, character)
    return { Line = line, Character = character }
end

---Creates a TextDocumentPositionParams from a documentUri , line number and character number
---@param documentUri string
---@param line integer
---@param character integer
---@return lsp.TextDocumentPositionParams
function M.TextDocumentPositionParams(documentUri, line, character)
    return {
        TextDocument = M.handlers.TextDocumentIdentifier(documentUri),
        Position = M.Position(line, character),
    }
end

---Creates an FSharpWorkspacePeekRequest from a directory string path, the workspaceModePeekDeepLevel integer and excludedDirs list
---@param directory string
---@param deep integer
---@param excludedDirs string[]
---@return FSharpWorkspacePeekRequest
function M.CreateFSharpWorkspacePeekRequest(directory, deep, excludedDirs)
    return {
        Directory = vim.fs.normalize(directory),
        Deep = deep,
        ExcludedDirs = excludedDirs,
    }
end

---creates an fsdn request.. probabably useless now..
---@param query string
---@return FsdnRequest
function M.FsdnRequest(query)
    return { Query = query }
end

function M.CallLspNotify(method, params)
    lsp.buf_notify(0, method, params)
end

function M.DotnetFile2Request(projectPath, currentVirtualPath, newFileVirtualPath)
    return {
        projectPath,
        currentVirtualPath,
        newFileVirtualPath,
    }
end

function M.CallFSharpAddFileAbove(projectPath, currentVirtualPath, newFileVirtualPath, handler)
    return M.handlers.Call(
        "fsharp/addFileAbove",
        M.DotnetFile2Request(projectPath, currentVirtualPath, newFileVirtualPath),
        handler
    )
end

function M.CallFSharpSignature(filePath, line, character, handler)
    return M.handlers.Call("fsharp/signature", M.TextDocumentPositionParams(filePath, line, character), handler)
end

function M.CallFSharpSignatureData(filePath, line, character, handler)
    return M.handlers.Call("fsharp/signatureData", M.TextDocumentPositionParams(filePath, line, character), handler)
end

function M.CallFSharpLineLens(projectPath, handler)
    return M.handlers.Call("fsharp/lineLens", M.handlers.CreateFSharpProjectParams(projectPath), handler)
end

function M.CallFSharpCompilerLocation(handler)
    return M.handlers.Call("fsharp/compilerLocation", {}, handler)
end

---Calls "fsharp/compile" on the given project file
---@param projectPath string
---@return nil
---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.CallFSharpCompileOnProjectFile(projectPath, handler)
    return M.handlers.Call("fsharp/compile", M.handlers.CreateFSharpProjectParams(projectPath), handler)
end

---Calls "fsharp/workspacePeek" Lsp Endpoint of FsAutoComplete
---@param directoryPath string
---@param depth integer
---@param excludedDirs string[]
---@return nil
---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.CallFSharpWorkspacePeek(directoryPath, depth, excludedDirs, handler)
    ---@type vim.lsp.get_clients.Filter
    local lspFilter = {
        name = "ionide",
    }

    ---@type vim.lsp.Client
    local i = vim.lsp.get_clients(lspFilter)
    -- vim.notify("Lsp peek client " .. vim.inspect(i))
    -- i.

    return M.handlers.Call("fsharp/workspacePeek", M.CreateFSharpWorkspacePeekRequest(directoryPath, depth, excludedDirs))
end

---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.Fsdn(signature, handler)
    return M.handlers.Call("fsharp/fsdn", M.FsdnRequest(signature), handler)
end

---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.F1Help(filePath, line, character, handler)
    return M.handlers.Call("fsharp/f1Help", M.TextDocumentPositionParams(filePath, line, character), handler)
end

--- call to "fsharp/documentation"
--- first creates a TextDocumentPositionParams,
--- requests data about symbol at given position, used for InfoPanel
---@param filePath string
---@param line integer
---@param character integer
---@return nil
---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.CallFSharpDocumentation(filePath, line, character, handler)
    return M.handlers.Call("fsharp/documentation", M.TextDocumentPositionParams(filePath, line, character), handler)
end

---Calls "fsharp/documentationSymbol" Lsp endpoint on FsAutoComplete
---creates a DocumentationForSymbolRequest then sends that request to FSAC
---@param xmlSig string
---@param assembly string
---@return nil
---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.CallFSharpDocumentationSymbol(xmlSig, assembly, handler)
    return M.handlers.Call("fsharp/documentationSymbol", M.DocumentationForSymbolRequest(xmlSig, assembly), handler)
end

---this should take the settings.FSharp table
---@param newSettingsTable _.lspconfig.settings.fsautocomplete.FSharp
function M.UpdateServerConfig(newSettingsTable)
    -- local input = vim.fn.input({ prompt = "Attach your debugger, to process " .. vim.inspect(vim.fn.getpid()) })
    M.CallLspNotify("workspace/didChangeConfiguration", newSettingsTable)
end

function M.ShowLoadedProjects()
    for proj, projInfo in pairs(M.Projects) do
        M.util.notify("- " .. vim.fs.normalize(proj))
    end
end

function M.ShowIonideClientWorkspaceFolders()
    ---@type lsp.Client|nil
    local client = M.getIonideClientAttachedToCurrentBufferOrFirstInActiveClients()
    if client then
        local folders = client.workspace_folders or {}
        M.util.notify("WorkspaceFolders: \n" .. vim.inspect(folders))
    else
        M.util.notify("No ionide client found, no workspace folders to show! \n")
    end
end

function M.ShowNvimSettings()
    M.util.notify("NvimSettings: \n" .. vim.inspect(M.config.MergedConfig.IonideNvimSettings))
end

function M.ShowConfigs()
    -- util.notify("Last passed in Config: \n" .. vim.inspect(config.PassedInConfig))
    M.util.notify("Last final merged Config: \n" .. vim.inspect(M.config.MergedConfig))
    M.ShowIonideClientWorkspaceFolders()
end

function M.Initialize()
    if not vim.fn.has("nvim") then
        M.util.notify("WARNING - This version of Ionide is only for NeoVim. please try Ionide/Ionide-Vim instead. ")
        return
    end

    M.util.notify("Initializing")

    M.util.notify("Calling updateServerConfig...")
    M.UpdateServerConfig(M.config.MergedConfig.settings.FSharp)

    M.util.notify("Setting Keymaps...")
    -- TODO
    local commands = {
        ShowConfigs = M.ShowConfigs,
        ShowIonideClientWorkspaceFolders = M.ShowIonideClientWorkspaceFolders,
        ShowLoadedProjects = M.ShowLoadedProjects,
        projectFolders = M.projectFolders,
        ShowNvimSettings = M.ShowNvimSettings,
        getIonideClientConfigRootDirOrCwd = M.getIonideClientConfigRootDirOrCwd,
        CallFSharpWorkspacePeek = M.CallFSharpWorkspacePeek,
    }
    M.util.notify("Registering Autocommands...")
    M.autocmds.setupAutoCommands(commands)

    M.util.notify("Fully Initialized!")
    local thisBufnr = vim.api.nvim_get_current_buf()
    local root_dir = M.util.GitFirstRootDir(api.nvim_buf_get_name(thisBufnr))
    ----@type vim.lsp.Client
    --local thisIonide = vim.lsp.get_clients({ bufnr = thisBufnr, name = "ionide" })[1]
    --or
    --local thisIonide = { workspace_folders = { { name = vim.fn.getcwd() } } }

    --local thisBufIonideRootDir = thisIonide.workspace_folders[1].name -- or vim.fn.getcwd()
    M.CallFSharpWorkspacePeek(
        root_dir,
        M.config.MergedConfig.settings.FSharp.workspaceModePeekDeepLevel,
        M.config.MergedConfig.settings.FSharp.excludeProjectDirectories
    )
end

function M.try_add(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    ---@diagnostic disable-next-line
    if api.nvim_buf_get_option(bufnr, "buftype") == "nofile" then
        return
    end
    local root_dir = M.util.GitFirstRootDir(api.nvim_buf_get_name(bufnr))
    local id = M.manager.add(root_dir)
    if id then
        lsp.buf_attach_client(bufnr, id)
    end
end

function M.try_add_wrapper(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    ---@diagnostic disable-next-line
    local buftype = api.nvim_buf_get_option(bufnr, "filetype")
    if buftype == "fsharp" then
        M.try_add(bufnr)
        return
    end
end

function M.Autostart()
    ---@type string
    M.util.notify("bufname: " .. vim.inspect(api.nvim_buf_get_name(0)))
    local root_dir = vim.fs.normalize(
        M.util.GitFirstRootDir(api.nvim_buf_get_name(0)) --, api.nvim_get_current_buf())
        or M.util.path.dirname(vim.fn.fnamemodify("%", ":p"))
        or vim.fn.getcwd()
    )
    api.nvim_command(
        string.format("autocmd %s lua require'ionide'.try_add_wrapper()",
            "BufReadPost " .. root_dir .. "/*")
    )
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local buf_dir = api.nvim_buf_get_name(bufnr)
        if buf_dir:sub(1, root_dir:len()) == root_dir then
            M.try_add_wrapper(bufnr)
        end
    end
end

function M.MakeConfig(_root_dir)
    ---@type lspconfig.options.fsautocomplete
    local new_config = vim.tbl_deep_extend("keep", vim.empty_dict(), config)
    new_config = vim.tbl_deep_extend("keep", new_config, M.config.DefaultLspConfig)
    new_config.capabilities = new_config.capabilities or lsp.protocol.make_client_capabilities()
    new_config.capabilities = vim.tbl_deep_extend("keep", new_config.capabilities, {
        workspace = {
            configuration = true,
        },
    })
    if config.on_new_config then
        pcall(config.on_new_config, new_config, _root_dir)
    end
    new_config.on_init = M.util.add_hook_after(new_config.on_init, function(client, _result)
        function client.workspace_did_change_configuration(settings)
            if not settings then
                return
            end
            if vim.tbl_isempty(settings) then
                settings = { [vim.type_idx] = vim.types.dictionary }
            end
            return client.notify("workspace/didChangeConfiguration", {
                settings = settings,
            })
        end

        if not vim.tbl_isempty(new_config.settings) then
            client.workspace_did_change_configuration(new_config.settings)
        end
    end)
    new_config._on_attach = new_config.on_attach
    new_config.on_attach = vim.schedule_wrap(function(client, bufnr)
        if bufnr == api.nvim_get_current_buf() then
            M._setup_buffer(client.id, bufnr)
        else
            api.nvim_command(
                string.format(
                    "autocmd BufEnter <buffer=%d> ++once lua require'ionide'._setup_buffer(%d,%d)",
                    bufnr,
                    client.id,
                    bufnr
                )
            )
        end
    end)
    new_config.root_dir = _root_dir
    return new_config
end

---Create Ionide Manager
---@param config IonideOptions
function M.CreateManager(conf)
    --validate({
    --    cmd = { config.cmd, "t", true },
    --    root_dir = { config.root_dir, "f", true },
    --    filetypes = { config.filetypes, "t", true },
    --    on_attach = { config.on_attach, "f", true },
    --    on_new_config = { config.on_new_config, "f", true },
    --})
    config = vim.tbl_deep_extend("keep", conf, M.config.DefaultLspConfig)
    M.get_root_dir = config.root_dir


    local reload = false
    if M.Manager then
        for _, client in ipairs(M.Manager.clients()) do
            client.stop(true)
        end
        reload = true
        M.Manager = nil
    end
    M.config.setupLspConfig(M.handlers.CreateHandlers(), M.Initialize)


    M.manager = M.util.server_per_root_dir_manager(function(_root_dir)
        return M.MakeConfig(_root_dir)
    end)


    if reload then
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            M.try_add_wrapper(bufnr)
        end
    else
        M.Autostart()
    end
end

-- partially adopted from neovim/nvim-lspconfig, see lspconfig.LICENSE.md
function M._setup_buffer(client_id, bufnr)
    local client = lsp.get_client_by_id(client_id)
    if not client then
        return
    end
    if client.config._on_attach then
        client.config._on_attach(client, bufnr)
    end
end

function M.status()
    if M.Manager then
        if next(M.Manager.clients()) == nil then
            print("* LSP server: not started")
        else
            print("* LSP server: started")
        end
    else
        print("* LSP server: not initialized")
    end
end

function M.getManager()
    return M.manager
end

return M
