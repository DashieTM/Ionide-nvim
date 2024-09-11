local uc = vim.api.nvim_create_user_command
local autocmd = vim.api.nvim_create_autocmd
local grp = vim.api.nvim_create_augroup
local handlers = require("plugin.handlers")
local util = require("plugin.util")

local M = {}
M.config = require("plugin.config")

function M.setupAutoCommands(commands)
    M.filetypeCommands()
    --M.bufReadPost()
    M.bufWritePost()
    M.registerLSPAutocmds()
    uc("IonideTestDocumentationForSymbolRequestParsing", function()
        M.CallFSharpDocumentationSymbol("T:System.String.Trim", "netstandard")
    end, { desc = "testing out the call to the symbol request from a hover" })
    -- TODO FSI
    --uc("IonideSendCurrentLineToFSI", commands.SendLineToFsi,
    --    { desc = "Ionide - Send Current line's text to FSharp Interactive" })
    --uc("IonideSendWholeBufferToFSI", commands.SendAllToFsi,
    --    { desc = "Ionide - Send Current buffer's text to FSharp Interactive" })
    --uc("IonideToggleFSI", M.ToggleFsi, { desc = "Ionide - Toggle FSharp Interactive" })
    --uc("IonideQuitFSI", M.QuitFsi, { desc = "Ionide - Quit FSharp Interactive" })
    --uc("IonideResetFSI", M.ResetFsi, { desc = "Ionide - Reset FSharp Interactive" })

    uc("IonideShowConfigs", commands.ShowConfigs, { desc = "Shows the merged config." })
    uc("IonideShowWorkspaceFolders", commands.ShowIonideClientWorkspaceFolders, {})
    uc("IonideLoadProjects", function(opts)
        if not opts.fargs[1] then
            M.notify("Please call this function with projects to load.")
        end
        --if opts.fargs[2] then
        --    local projects = {}
        --    for _, proj in ipairs(opts.fargs[1]) do
        --        table.insert(projects, proj)
        --    end
        --    M.LoadProjects(projects)
        --end
        if type(opts.fargs[1]) == "string" then
            M.LoadProjects({ opts.fargs[1] })
        elseif type(opts.fargs[1]) == "table" then
            local projects = opts.fargs[1]
            M.LoadProjects(projects)
        end
    end, {})

    uc("IonideShowLoadedProjects", commands.ShowLoadedProjects,
        { desc = "Shows just the project names that have been loaded." })
    uc("IonideShowNvimSettings", commands.ShowNvimSettings, {})
    uc("IonideShowAllLoadedProjectInfo", function()
        util.notify(M.Projects)
    end, { desc = "Show all currently loaded Project Info" })
    uc("IonideShowAllLoadedProjectFolders", function()
        util.notify(table.concat(commands.projectFolders, "\n"))
    end, { desc = "Show all currently loaded project folders" })
    uc("IonideWorkspacePeek", function()
        local settingsFSharp = M.config.DefaultServerSettings
        if M.config.MergedConfig.settings and M.config.MergedConfig.settings.FSharp then
            settingsFSharp = M.config.MergedConfig.settings.FSharp
        end
        commands.CallFSharpWorkspacePeek(
            commands.getIonideClientConfigRootDirOrCwd(),
            settingsFSharp.workspaceModePeekDeepLevel or 10,
            settingsFSharp.excludeProjectDirectories or {}
        )
    end, { desc = "Request a workspace peek from Lsp" })
end

--- ftplugin section ---
function M.filetypeCommands()
    vim.filetype.add({
        extension = {
            fsproj = function(_, _)
                return "fsharp_project",
                    function(bufnr)
                        vim.bo[bufnr].syn = "xml"
                        vim.bo[bufnr].ro = false
                        vim.b[bufnr].readonly = false
                        vim.bo[bufnr].commentstring = "<!--%s-->"
                        -- vim.bo[bufnr].comments = "<!--,e:-->"
                        vim.opt_local.foldlevelstart = 99
                        vim.w.fdm = "syntax"
                    end
            end,
        },
    })

    vim.filetype.add({
        extension = {
            fs = function(path, bufnr)
                return "fsharp",
                    function(bufnr)
                        if not vim.g.filetype_fs then
                            vim.g["filetype_fs"] = "fsharp"
                        end
                        if not vim.g.filetype_fs == "fsharp" then
                            vim.g["filetype_fs"] = "fsharp"
                        end
                        vim.w.fdm = "syntax"
                        -- comment settings
                        vim.bo[bufnr].formatoptions = "croql"
                        -- vim.bo[bufnr].commentstring = "(*%s*)"
                        vim.bo[bufnr].commentstring = "//%s"
                        vim.bo[bufnr].comments = [[s0:*\ -,m0:*\ \ ,ex0:*),s1:(*,mb:*,ex:*),:\/\/\/,:\/\/]]
                    end
            end,
            fsx = function(path, bufnr)
                return "fsharp",
                    function(bufnr)
                        if not vim.g.filetype_fs then
                            vim.g["filetype_fsx"] = "fsharp"
                        end
                        if not vim.g.filetype_fs == "fsharp" then
                            vim.g["filetype_fsx"] = "fsharp"
                        end
                        vim.w.fdm = "syntax"
                        -- comment settings
                        vim.bo[bufnr].formatoptions = "croql"
                        vim.bo[bufnr].commentstring = "//%s"
                        -- vim.bo[bufnr].commentstring = "(*%s*)"
                        vim.bo[bufnr].comments = [[s0:*\ -,m0:*\ \ ,ex0:*),s1:(*,mb:*,ex:*),:\/\/\/,:\/\/]]
                    end
            end,
        },
    })
end

---call to "fsharp/project" - which, after using projectPath to create an FSharpProjectParms, loads given project
---@param projectPath string
---@return nil
---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.CallFSharpProject(projectPath)
    return handlers.Call("fsharp/project", handlers.CreateFSharpProjectParams(projectPath))
end

---Loads the given projects list.
---@param projects string[] -- projects only
function M.LoadProjects(projects)
    if projects then
        handlers.CallFSharpWorkspaceLoad(projects)
    end
end

function M.ReloadProjects()
    util.notify("Reloading Projects")
    --local foldersCount = #M.projectFolders
    --if foldersCount > 0 then
    --handlers.CallFSharpWorkspaceLoad(M.projectFolders)
    --else
    --    util.notify("Workspace is empty")
    --end
end

-- TODO
-- TODO TODO TODO
function M.OnFSProjSave()
    if
        vim.bo.ft == "fsharp_project"
        and M.config.MergedConfig.IonideNvimSettings.AutomaticReloadWorkspace
        and M.config.MergedConfig.IonideNvimSettings.AutomaticReloadWorkspace == true
    then
        util.notify("fsharp project saved, reloading...")
        -- TODO
        --local parentDir = vim.fs.normalize(vim.fs.dirname(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())))

        --if not vim.tbl_contains(M.projectFolders, parentDir) then
        --    table.insert(M.projectFolders, parentDir)
        --end
        M.ReloadProjects()
    end
end

function M.bufWritePost()
    autocmd("BufWritePost", {
        pattern = "*.fsproj",
        desc = "FSharp Auto refresh on project save",
        group = vim.api.nvim_create_augroup("FSProjRefreshOnProjectSave", { clear = true }),
        callback = function()
            M.OnFSProjSave()
        end,
    })
end

function M.bufReadPost()
    autocmd({ "BufReadPost" }, {
        desc = "FSharp start Ionide on fsharp_project load",
        group = grp("FSProjStartIonide", { clear = true }),
        pattern = "*.fsproj",
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
            local projectRoot = vim.fs.normalize(util.GitFirstRootDir(bufname))

            -- util.notify("Searching for Ionide client already started for root path of " .. projectRoot )
            local parentDir = vim.fs.normalize(vim.fs.dirname(bufname))
            local closestFsFile = vim.fs.find(function(name, path)
                return name:match(".*%.fs$")
            end, { limit = 1, type = "file", upward = true, path = parentDir, stop = projectRoot })[1] or (function()
                local newFile = parentDir .. "/" .. vim.inspect(os.time()) .. "TempFileForProjectInitDeleteMe.fs"
                vim.fn.writefile({}, newFile)
                return newFile
            end)()

            -- util.notify("closest fs file is  " .. closestFsFile )
            ---@type integer
            local closestFileBufNumber = vim.fn.bufadd(closestFsFile)
            local ionideClientsList = vim.lsp.get_clients({ name = "ionide" })
            local isAleadyStarted = false
            if ionideClientsList then
                for _, client in ipairs(ionideClientsList) do
                    local root = client.config.root_dir or ""
                    if vim.fs.normalize(root) == projectRoot then
                        -- util.notify("Ionide already started for root path of " .. projectRoot .. " \nClient Id: " .. vim.inspect(client.id))
                        isAleadyStarted = true
                        break
                    end
                end
            else
            end
            if not isAleadyStarted then
                vim.defer_fn(function()
                    vim.cmd.tcd(projectRoot)
                    vim.cmd.e(closestFsFile)
                    vim.cmd.b(bufnr)
                    vim.cmd.bd(closestFileBufNumber)
                end, 100)
            end
        end,
    })
end

function M.registerLSPAutocmds()
    autocmd({ "LspAttach" }, {
        desc = "FSharp clear code lens on attach ",
        group = grp("FSharp_ClearCodeLens", { clear = true }),
        pattern = "*.fs,*.fsi,*.fsx",
        callback = function(args)
            local codelensConfig = {
                references = { enabled = false },
                signature = { enabled = false },
            }
            if M.config.MergedConfig.settings and M.config.MergedConfig.settings.FSharp and M.config.MergedConfig.settings.FSharp.codeLenses then
                codelensConfig = M.config.MergedConfig.settings.FSharp.codeLenses
            end
            if codelensConfig.references.enabled == true or codelensConfig.signature.enabled == true then
                vim.defer_fn(function()
                    vim.lsp.codelens.clear()
                    vim.lsp.codelens.refresh()
                    vim.lsp.codelens.refresh()
                    -- util.notify("lsp codelens refreshing")
                end, 7000)
            end
        end,
    })

    --autocmd({ "LspAttach" }, {
    --    desc = "FSharp enable inlayHint on attach ",
    --    group = grp("FSharp_enableInlayHint", { clear = true }),
    --    pattern = "*.fs,*.fsi,*.fsx",
    --    callback = function(args)
    --        -- args.data.client_id
    --        if M.config.MergedConfig.settings.FSharp.inlayHints.enabled == true then
    --            vim.defer_fn(function()
    --                -- util.notify("enabling lsp inlayHint")
    --                if vim.lsp.buf.inlay_hint then
    --                    vim.lsp.buf.inlay_hint(args.buf, true)
    --                elseif vim.lsp.inlay_hint then
    --                    vim.lsp.inlay_hint.enable(true)
    --                else
    --                end
    --            end, 2000)
    --        else
    --            -- util.notify("lsp inlayHints are not enabled.")
    --        end
    --    end,
    --})

    autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        desc = "FSharp Auto refresh code lens ",
        group = grp("IonideAutomaticCodeLensRefresh", { clear = true }),
        pattern = "*.fs,*.fsi,*.fsx",
        callback = function(arg)
            if
                M.config.MergedConfig.settings.FSharp.codeLenses.references.enabled == true
                or M.config.MergedConfig.settings.FSharp.codeLenses.references.enabled == true
            then
                if M.config.MergedConfig.IonideNvimSettings.AutomaticCodeLensRefresh == true then
                    vim.defer_fn(function()
                        vim.lsp.codelens.refresh()
                        -- util.notify("lsp codelens refreshing")
                    end, 2000)
                end
            end
        end,
    })

    --autocmd({ "CursorHold", "CursorHoldI", "InsertLeave" }, {
    --    desc = "Ionide Show Signature on cursor move or hold",
    --    group = grp("FSharp_ShowSignatureOnCursorMoveOrHold", { clear = true }),
    --    pattern = "*.fs,*.fsi,*.fsx",
    --    callback = function()
    --        if config.MergedConfig.IonideNvimSettings.ShowSignatureOnCursorMove == true then
    --            vim.defer_fn(function()
    --                local pos = vim.inspect_pos(
    --                    vim.api.nvim_get_current_buf(),
    --                    nil,
    --                    nil,
    --                    ---@type InspectorFilter
    --                    {
    --                        extmarks = false,
    --                        syntax = false,
    --                        semantic_tokens = false,
    --                        treesitter = false,
    --                    }
    --                )
    --                M.CallFSharpSignature(vim.uri_from_bufnr(pos.buffer), pos.col, pos.row)
    --            end, 1000)
    --        end
    --    end,
    --})

    autocmd({ "BufReadPost" }, {
        desc = "Apply Recommended Colorscheme to Lsp Diagnostic and Code lenses.",
        group = grp("FSharp_ApplyRecommendedColorScheme", { clear = true }),
        pattern = "*.fs,*.fsi,*.fsx",
        callback = function()
            if M.config.MergedConfig.IonideNvimSettings.LspRecommendedColorScheme == true then
                M.ApplyRecommendedColorscheme()
            end
        end,
    })
end

---applies a recommended color scheme for diagnostics and CodeLenses
function M.ApplyRecommendedColorscheme()
    vim.cmd([[
    highlight! LspDiagnosticsDefaultError ctermbg=Red ctermfg=White
    highlight! LspDiagnosticsDefaultWarning ctermbg=Yellow ctermfg=Black
    highlight! LspDiagnosticsDefaultInformation ctermbg=LightBlue ctermfg=Black
    highlight! LspDiagnosticsDefaultHint ctermbg=Green ctermfg=White
    highlight! default link LspCodeLens Comment
]])
end

return M
