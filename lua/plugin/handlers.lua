local util = require("plugin.util")
local lsputil = require("vim.lsp.util")
local lsp = vim.lsp

local M = {
    Handlers = {},
    Projects = {},
    projectFolders = {}
}
--- Handlers ---

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
M["textDocument/documentHighlight"] = function(error, result, context, config)
    if error then
        util.notify("received error" .. error)
        return
    end
    if result then
        vim.lsp.handlers["textDocument/documentHighlight"](error, result, context, config)
    end
end

--let M.HoverParms = {}


M["textDocument/hover"] =
-- define types
--- @param error any
--- @param result lsp.Hover
--- @param context lsp.HandlerContext
--- @param config table Configuration table
    function(error, result, context, config)
        -- error received
        if error then
            util.notify("received error: " .. error.message)
            return
        end

        -- no result available
        if not result then
            util.notify("No information found")
        end
        -- (?s)<li>(?:(?!</li>).).*?</li>
        -- TODO remove the annoying link

        result.message = result.contents[1].value
        vim.lsp.handlers.hover(error, result, context or {}, config)
        -- vim.lsp.handlers.hover(error or {}, result or {}, context or {}, config or {})
    end

M["fsharp/showDocumentation"] = function(error, result, context, config)
    if error then
        util.notify("received error" .. error)
        return
    end
    util.notify(
        "handling "
        .. "fsharp/showDocumentation"
        .. " | "
        .. "result is: \n"
        .. vim.inspect({ error or "", result or "", context or "", config or "" })
    )
    if result then
        if result.content then
        end
    end
end
M["fsharp/documentationSymbol"] = function(error, result, context, config)
    if error then
        util.notify("received error" .. error)
        return
    end
    if result then
        if result.content then
        end
    end
end

M["fsharp/notifyWorkspace"] = function(payload)
    -- util.notify("handling notifyWorkspace")
    local content = vim.json.decode(payload.content)
    -- util.notify("notifyWorkspace Decoded content is : \n"..vim.inspect(content))
    if content then
        if content.Kind == "projectLoading" then
            util.notify("Loading " .. vim.fs.normalize(content.Data.Project))
            -- util.notify("now calling AddOrUpdateThenSort on table  " .. vim.inspect(Workspace))
            --
            -- table.insert( M.Projects, content.Data.Project)
            -- -- local dir = vim.fs.dirname(content.Data.Project)
            -- util.notify("after attempting to reassign table value it looks like this : " .. vim.inspect(Workspace))
        elseif content.Kind == "project" then
            local k = content.Data.Project
            local projInfo = {}
            projInfo[k] = content.Data

            M.Projects = vim.tbl_deep_extend("force", M.Projects, projInfo)
        elseif content.Kind == "workspaceLoad" and content.Data.Status == "finished" then
            -- util.notify("calling updateServerConfig ... ")
            -- util.notify("before calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))

            for proj, projInfoData in pairs(M.Projects) do
                local dir = vim.fs.dirname(proj)
                if vim.tbl_contains(M.projectFolders, dir) then
                else
                    table.insert(M.projectFolders, dir)
                end
            end
            -- util.notify("after calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
            local projectCount = vim.tbl_count(M.Projects)
            if projectCount > 0 then
                local projNames = lsputil.convert_input_to_markdown_lines(vim.tbl_map(function(s)
                    return vim.fn.fnamemodify(s, ":P:.")
                end, vim.tbl_keys(M.Projects)))
                if projectCount > 1 then
                    util.notify("Loaded " .. projectCount .. " projects:")
                else
                    util.notify("Loaded 1 project:")
                end
                for _, projName in pairs(projNames) do
                    util.notify("Loaded " .. vim.fs.normalize(vim.inspect(projName)))
                end
            else
                util.notify("Workspace is empty! Something went wrong. ")
            end
            local deleteMeFiles = vim.fs.find(function(name, _)
                return name:match(".*TempFileForProjectInitDeleteMe.fs$")
            end, { type = "file" })
            if deleteMeFiles then
                for _, file in ipairs(deleteMeFiles) do
                    pcall(os.remove, file)
                end
            end
        end
    end
end

M["fsharp/workspaceLoad"] = function(result)
    if not result then
        util.notify(
            "Failed to load workspave\n"
        )
        return
    end
end

function onChoice(finalChoice)
    util.notify("Loading solution : " .. vim.inspect(finalChoice))
    ---@type string[]
    local pathsToLoad = {}
    local projects = finalChoice.Data.Items
    for _, project in ipairs(projects) do
        if project.Name:match("sproj") then
            table.insert(pathsToLoad,
                vim.fs.normalize(project.Name))
        end
    end

    util.notify(
        "Going to ask FsAutoComplete to load these project paths.. " ..
        vim.inspect(pathsToLoad))
    local projectParams = {}
    for _, path in ipairs(pathsToLoad) do
        table.insert(projectParams,
            M.CreateFSharpProjectParams(path))
    end
    M.CallFSharpWorkspaceLoad(pathsToLoad)
    for _, proj in ipairs(projectParams) do
        vim.lsp.buf_request(0, "fsharp/project", { proj },
            function(payload) end)
    end
end

M["fsharp/workspacePeek"] = function(error, result, context, config)
    if not result then
        return
    end
    if error then
        util.notify("fsharp/workspacePeek error:" .. error)
    end
    local resultContent = result.content
    ---@type Solution []
    local solutions = {}
    local directory
    if resultContent == nil then
        util.notify("result was nil")
        return
    end
    local content = vim.json.decode(resultContent)
    if not content then
        util.notify("content was nil")
        return
    end
    local kind = content.Kind
    if kind ~= "workspacePeek" then
        util.notify("workspacePeek was expected but got" .. kind)
        return
    end
    local data = content.Data
    if data == nil then
        util.notify("data was nil")
        return
    end
    local found = data.Found
    if found == nil then
        util.notify("no projects found")
        return
    end
    ---@type Project[]
    local projects = {}
    for _, item in ipairs(found) do
        if item.Type == "solution" then
            table.insert(solutions, item)
        elseif item.Type == "directory" then
            directory = vim.fs.normalize(item.Data.Directory)
        elseif item.Kind.Kind == "msbuildformat" then
            table.insert(projects, item)
        else -- else left in case I want some other type to be dealt with..
            util.notify(
                "Unaccounted for item type in workspacePeek handler, " ..
                item.Type)
        end
    end
    local cwd = vim.fs.normalize(vim.fn.getcwd())
    if directory ~= cwd then
        util.notify(
            "WorkspacePeek directory \n" ..
            directory ..
            "Does not equal current working directory\n" ..
            cwd
        )
    end
    --local solutionToLoad
    local finalChoice
    if #solutions < 1 then
        util.notify(
            "Only one solution in workspace path, projects should be loaded already.")
        return
    end
    -- util.notify(vim.inspect(#solutions) .. " solutions found in workspace")
    if #solutions > 1 then
        -- util.notify("More than one solution found in workspace!")
        vim.ui.select(solutions, {
            prompt =
            "More than one solution found in workspace. Please pick one to load:",

            format_item = function(item)
                return vim.fn.fnamemodify(
                    vim.fs.normalize(item
                        .Data.Path),
                    ":p:.")
            end,
        }, function(_, index)
            finalChoice = solutions[index]
            onChoice(finalChoice)
        end)
    else
        finalChoice = solutions[1]
        if finalChoice then
            onChoice(finalChoice)
        else
            finalChoice = {
                Data = {
                    Path = vim.fn.getcwd(),
                    Items = {
                        Name = vim.fs.find(
                            function(name, _)
                                return name
                                    :match(
                                        ".*%.[cf]sproj$")
                            end,
                            { type = "file" }),
                    },
                },
            }
        end
        local finalPath = vim.fs.normalize(finalChoice.Data.Found[1].Data.Path)
        onChoice(finalPath)
    end
end



M["fsharp/compilerLocation"] = function(error, result, context, config)
    util.notify(
        "handling compilerLocation response\n"
        .. "result is: \n"
        .. vim.inspect({ error or "", result or "", context or "", config or "" })
    )
end

M["workspace/workspaceFolders"] = function(error, result, context, config)
    if result then
        util.notify(
            "handling workspace/workspaceFolders response\n"
            .. "result is: \n"
            .. vim.inspect({ error or "", result or "", context or "", config or "" })
        )
    end
    local client_id = context.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        -- vim.err_message("LSP[id=", client_id, "] client has shut down after sending the message")
        return
    end
    return client.workspace_folders or vim.NIL
end

M["fsharp/signature"] = function(error, result, context, config)
    if not result then
        util.notify("Result of signature was none")
        return
    end
    if not result.result then
        util.notify("Result of signature was none")
        return
    end
    if not result.result.content then
        util.notify("Result of signature was none")
        return
    end
    local content = vim.json.decode(result.result.content)
    if not content then
        util.notify("Result of signature was none")
        return
    end
    if not content.Data then
        return
    end
    -- Using gsub() instead of substitute() in Lua
    -- and % instead of :
    util.notify(content.Data:gsub("\n+$", " "))
end






function M.CreateHandlers()
    local h = {
        "fsharp/notifyWorkspace",
        "fsharp/documentationSymbol",
        "fsharp/workspacePeek",
        "fsharp/workspaceLoad",
        "fsharp/compilerLocation",
        "fsharp/signature",
        "textDocument/hover",
        "textDocument/documentHighlight",
    }
    local r = {}
    for _, method in ipairs(h) do
        r[method] = function(err, params, ctx, config)
            if method == "fsharp/compilerLocation" then
                M[method](err or nil, params or {}, ctx or {},
                    config or {})
            elseif method == "fsharp/documentationSymbol" then
                M[method](err or nil, params or {}, ctx or {},
                    config or {})
            elseif method == "textDocument/hover" then
                M[method](err or nil, params or {}, ctx or {},
                    config or {})
            else
                M[method](params)
            end
        end
    end
    M.Handlers = vim.tbl_deep_extend("force", M.Handlers, r)
    return r
end

---Call to "fsharp/workspaceLoad"
---@param projectFiles string[]  a string list of project files.
---@return nil
---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.CallFSharpWorkspaceLoad(projectFiles, handler)
    return M.Call("fsharp/workspaceLoad", M.CreateFSharpWorkspaceLoadParams(projectFiles), handler)
end

---creates a ProjectParms for fsharp/project call
---@param projectUri string
---@return FSharpProjectParams
function M.CreateFSharpProjectParams(projectUri)
    return {
        Project = M.TextDocumentIdentifier(projectUri),
    }
end

---creates a textDocumentIdentifier from a string path
---@param path string
---@return lsp.TextDocumentIdentifier
function M.TextDocumentIdentifier(path)
    local is_windows = vim.loop.os_uname().version:match("Windows")
    local usr_ss_opt
    if is_windows then
        usr_ss_opt = vim.o.shellslash
        vim.o.shellslash = true
    end
    local uri = vim.fn.fnamemodify(path, ":p")
    if string.sub(uri, 1, 1) == "/" then
        uri = "file://" .. uri
    else
        uri = "file:///" .. uri
    end
    if is_windows then
        vim.o.shellslash = usr_ss_opt
    end
    ---
    ---@type lsp.TextDocumentIdentifier
    return { Uri = uri }
end

---Creates FSharpWorkspaceLoadParams from the string list of Project files to load given.
---@param files string[] -- project files only..
---@return FSharpWorkspaceLoadParams
function M.CreateFSharpWorkspaceLoadParams(files)
    local prm = {}
    for _, file in ipairs(files) do
        -- if stringEndsWith(file,"proj") then
        table.insert(prm, M.TextDocumentIdentifier(file))
        -- end
    end
    return { TextDocuments = prm }
end

---Calls the Lsp server endpoint with the method name, parameters
---@param method (string) LSP method name
---@param params table|nil Parameters to send to the server
---@param handler function|nil optional handler to use instead of the default method.
--- if nil then it will try to use the method of the same name
--- in M.Handlers from Ionide, if it exists.
--- if that returns nil, then the vim.lsp.buf_notify() request
--- should fallback to the normal built in
--- vim.lsp.handlers\[["some/lspMethodNameHere"]\] general execution strategy
---
---@return table<integer, integer>, fun() 2-tuple:
---  - Map of client-id:request-id pairs for all successful requests.
---  - Function which can be used to cancel all the requests. You could instead
---    iterate all clients and call their `cancel_request()` methods.
function M.Call(method, params, handler)
    ---@type lsp-handler
    handler = handler or M[method]
    return lsp.buf_request(0, method, params, handler)
end

return M
