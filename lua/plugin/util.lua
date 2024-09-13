-- adopted from neovim/nvim-lspconfig, see lspconfig.LICENSE.md

local vim = vim
local validate = vim.validate
local api = vim.api
local lsp = vim.lsp
local uv = vim.loop
local fn = vim.fn

local M = {}


function M.validate_bufnr(bufnr)
    validate {
        bufnr = { bufnr, "n" },
    }
    return bufnr == 0 and api.nvim_get_current_buf() or bufnr
end

function M.add_hook_before(func, new_fn)
    if func then
        return function(...)
            -- TODO which result?
            new_fn(...)
            return func(...)
        end
    else
        return new_fn
    end
end

function M.add_hook_after(func, new_fn)
    if func then
        return function(...)
            -- TODO which result?
            func(...)
            return new_fn(...)
        end
    else
        return new_fn
    end
end

function M.create_module_commands(module_name, commands)
    for command_name, def in pairs(commands) do
        local parts = { "command!" }
        -- Insert attributes.
        for k, v in pairs(def) do
            if type(k) == "string" and type(v) == "boolean" and v then
                table.insert(parts, "-" .. k)
            elseif type(k) == "number" and type(v) == "string" and v:match "^%-" then
                table.insert(parts, v)
            end
        end
        table.insert(parts, command_name)
        -- The command definition.
        table.insert(
            parts,
            string.format("lua require'lspconfig'[%q].commands[%q][1](<f-args>)", module_name, command_name)
        )
        api.nvim_command(table.concat(parts, " "))
    end
end

function M.has_bins(...)
    for i = 1, select("#", ...) do
        if 0 == fn.executable((select(i, ...))) then
            return false
        end
    end
    return true
end

M.script_path = function()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match "(.*[/\\])"
end

-- Some path utilities
M.path = (function()
    local function exists(filename)
        local stat = uv.fs_stat(filename)
        return stat and stat.type or false
    end

    local function is_dir(filename)
        return exists(filename) == "directory"
    end

    local function is_file(filename)
        return exists(filename) == "file"
    end

    local is_windows = uv.os_uname().version:match "Windows"
    local path_sep = is_windows and "\\" or "/"

    local is_fs_root
    if is_windows then
        is_fs_root = function(path)
            return path:match "^%a:$"
        end
    else
        is_fs_root = function(path)
            return path == "/"
        end
    end

    local function is_absolute(filename)
        if is_windows then
            return filename:match "^%a:" or filename:match "^\\\\"
        else
            return filename:match "^/"
        end
    end

    local dirname
    do
        local strip_dir_pat = path_sep .. "([^" .. path_sep .. "]+)$"
        local strip_sep_pat = path_sep .. "$"
        dirname = function(path)
            if not path or #path == 0 then
                return
            end
            local result = path:gsub(strip_sep_pat, ""):gsub(strip_dir_pat, "")
            if #result == 0 then
                return "/"
            end
            return result
        end
    end

    local function path_join(...)
        local result = table.concat(vim.tbl_flatten { ... }, path_sep):gsub(path_sep .. "+", path_sep)
        return result
    end

    -- Traverse the path calling cb along the way.
    local function traverse_parents(path, cb)
        path = uv.fs_realpath(path)
        local dir = path
        -- Just in case our algo is buggy, don't infinite loop.
        for _ = 1, 100 do
            dir = dirname(dir)
            if not dir then
                return
            end
            -- If we can't ascend further, then stop looking.
            if cb(dir, path) then
                return dir, path
            end
            if is_fs_root(dir) then
                break
            end
        end
    end

    -- Iterate the path until we find the rootdir.
    local function iterate_parents(path)
        path = uv.fs_realpath(path) or path
        local function it(s, v)
            if not v then
                return
            end
            if is_fs_root(v) then
                return
            end
            return dirname(v), path
        end
        return it, path, path
    end

    local function is_descendant(root, path)
        if not path then
            return false
        end

        local function cb(dir, _)
            return dir == root
        end

        local dir, _ = traverse_parents(path, cb)

        return dir == root
    end

    return {
        is_dir = is_dir,
        is_file = is_file,
        is_absolute = is_absolute,
        exists = exists,
        sep = path_sep,
        dirname = dirname,
        join = path_join,
        traverse_parents = traverse_parents,
        iterate_parents = iterate_parents,
        is_descendant = is_descendant,
    }
end)()

-- Returns a function(root_dir), which, when called with a root_dir it hasn't
-- seen before, will call make_config(root_dir) and start a new client.
function M.server_per_root_dir_manager(_make_config)
    local clients = {}
    local manager = {}

    function manager.add(root_dir)
        if not root_dir then
            return
        end
        if not M.path.is_dir(root_dir) then
            return
        end

        -- Check if we have a client alredy or start and store it.
        local client_id = clients[root_dir]
        if not client_id then
            local new_config = _make_config(root_dir)
            --TODO:mjlbach -- these prints only show up with nvim_error_writeln()
            if not new_config.cmd then
                print(
                    string.format(
                        "Error, cmd not defined for [%q]."
                        .. "You must manually define a cmd for the default config for this server."
                        .. "See server documentation.",
                        new_config.name
                    )
                )
                return
            elseif vim.fn.executable(new_config.cmd[1]) == 0 then
                vim.notify(string.format("cmd [%q] is not executable.", new_config.cmd[1]), vim.log.levels.Error)
                return
            end
            new_config.on_exit = M.add_hook_before(new_config.on_exit, function()
                clients[root_dir] = nil
            end)
            client_id = lsp.start_client(new_config)
            clients[root_dir] = client_id
        end
        return client_id
    end

    function manager.clients()
        local res = {}
        for _, id in pairs(clients) do
            local client = lsp.get_client_by_id(id)
            if client then
                table.insert(res, client)
            end
        end
        return res
    end

    return manager
end

function M.search_ancestors(startpath, func)
    validate { func = { func, "f" } }
    if func(startpath) then
        return startpath
    end
    for path in M.path.iterate_parents(startpath) do
        if func(path) then
            return path
        end
    end
end

function M.root_pattern(...)
    local patterns = vim.tbl_flatten { ... }
    local function matcher(path)
        for _, pattern in ipairs(patterns) do
            for _, p in ipairs(vim.fn.glob(M.path.join(path, pattern), true, true)) do
                if M.path.exists(p) then
                    return path
                end
            end
        end
    end
    return function(startpath)
        return M.search_ancestors(startpath, matcher)
    end
end

function M.find_git_ancestor(startpath)
    return M.search_ancestors(startpath, function(path)
        if M.path.is_dir(M.path.join(path, ".git")) then
            return path
        end
    end)
end

function M.find_node_modules_ancestor(startpath)
    return M.search_ancestors(startpath, function(path)
        if M.path.is_dir(M.path.join(path, "node_modules")) then
            return path
        end
    end)
end

function M.find_package_json_ancestor(startpath)
    return M.search_ancestors(startpath, function(path)
        if M.path.is_file(M.path.join(path, "package.json")) then
            return path
        end
    end)
end

function M.notify(msg, level, opts)
    local safeMessage = "[Ionide] - "
    if type(msg) == "string" then
        safeMessage = safeMessage .. msg
    else
        safeMessage = safeMessage .. vim.inspect(msg)
    end
    vim.notify(safeMessage, level, opts)
end

function M.GitFirstRootDir(n)
    local root
    root = M.find_git_ancestor(n)
    root = root or M.root_pattern("*.sln")(n)
    root = root or M.root_pattern("*.fsproj")(n)
    root = root or M.root_pattern("*.fsx")(n)
    return root
end

---@param input string
---@return string
local function unHtmlify(input)
    input = input or ""
    -- print("unHtmlify input: " .. input)
    local result
    if #input > 2 then
        result = input:gsub("%%%x%x", function(entity)
            entity = entity or ""
            if #entity > 2 then
                return string.char(tonumber(entity:sub(2), 16))
            else
                return entity
            end
        end)
    else
        result = input
    end
    -- print("unHtmlify result: " .. result)
    return result
end

function M.returnFuncNameToCallFromCapture(s)
    local result = ((s or ""):gsub("%.", "/")) -- print("funcName match result : " .. result)
    result = string.gsub(result, "showDocumentation", "documentationSymbol")

    return result
end

---matches a document signature command request originally meant for vscode's commands
---@param s string
---@return string|nil, string|nil
function M.matchFsharpDocSigRequest(s)
    local link_pattern = "<a href='command:(.-)%?(.-)'>"
    return string.match(s, link_pattern)
end

--- gets the various parts given by hover request and returns them
---@param input_string string
---function name
---@return string
---escapedHtml
---@return string
---DocumentationForSymbolRequest
---@return FSharpDocumentationForSymbolRequest
---label
---@return string
local function parse_string(input_string)
    local function_capture, json_capture = M.matchFsharpDocSigRequest(input_string)
    if function_capture then
        M.util.notify(function_capture)
        if json_capture then
            M.util.notify(json_capture)
            local function_name = M.returnFuncNameToCallFromCapture(function_capture)
            local unHtml = unHtmlify(json_capture)
            unHtml = unHtml
            -- print("unHtml :", unHtml)
            local decoded = (vim.json.decode(unHtml) or {
                {
                    XmlDocSig = "NoProperSigGiven",
                    AssemblyName = "NoProperAssemblyGiven",
                },
            })[1]
            -- util.notify("after decode: " .. vim.inspect(decoded))
            ---@type FSharpDocumentationForSymbolRequest
            local decoded_json = M.DocumentationForSymbolRequest(decoded.XmlDocSig, decoded.AssemblyName)
            M.util.notify({ "as symbolrequest: ", decoded_json })
            local label_text = input_string:match(">(.-)<")
            return function_name, unHtml, decoded_json, label_text
        else
            return input_string, "",
                M.DocumentationForSymbolRequest("NoProperSigGiven", "NoProperAssemblyGiven"), ""
        end
        return input_string, "", M.DocumentationForSymbolRequest("NoProperSigGiven", "NoProperAssemblyGiven"), ""
    end
    return input_string, "", M.DocumentationForSymbolRequest("NoProperSigGiven", "NoProperAssemblyGiven"), ""
end

local function split_lines(value)
    value = string.gsub(value, "\r\n?", "\n")
    return vim.split(value, "\n", { trimempty = true })
end

function M.FormatHover(input, contents)
    -- -- value = string.gsub(value, "\r\n?", "\n")
    -- local thisIonide = vim.lsp.get_active_clients({ name = "ionide" })[1]
    local result
    contents = contents or {}

    if type(input) == "string" then
        -- local lines = vim.split(value, "\n", { trimempty = true })
        local parsedOrFunctionName, escapedHtml, decodedJsonTable, labelText = parse_string(input)
        if input == parsedOrFunctionName then
            -- print("no Match for line " .. line)
            result = input
        else
            if decodedJsonTable then
                -- result = ""
                --   .. " "
                --   .. "FunctionToCall: "
                --   .. parsedOrFunctionName
                --   .. " WithParams: "
                --   .. vim.inspect(decodedJsonTable)
                -- if not line == parsedOrFunctionName then
                -- print("decoded json looks like : " .. vim.inspect(decodedJsonTable))
                -- print(decodedJsonTable.XmlDocSig, decodedJsonTable.AssemblyName)
                -- if thisIonide then
                -- M.DocumentationForSymbolRequest(decodedJsonTable.XmlDocSig, decodedJsonTable.AssemblyName)
                vim.schedule_wrap(function()
                    vim.lsp.buf_request(0, parsedOrFunctionName, decodedJsonTable, function(e, r)
                        result = vim.inspect(e) .. vim.inspect(r)
                        -- util.notify("results from request " .. vim.inspect(parsedOrFunctionName) .. ":" .. result)
                        table.insert(contents, result)
                    end)
                end)
                -- else
                -- print("noActiveIonide.. probably testing ")
                -- end
            else
                print("no decoded json")
            end
        end
    else
        -- MarkupContent
        if input.kind then
            -- The kind can be either plaintext or markdown.
            -- If it's plaintext, then wrap it in a <text></text> block

            -- Some servers send input.value as empty, so let's ignore this :(
            local value = input.value or ""

            if input.kind == "plaintext" then
                -- wrap this in a <text></text> block so that stylize_markdown
                -- can properly process it as plaintext
                value = string.format("<text>\n%s\n</text>", value)
            end

            -- assert(type(value) == 'string')
            vim.list_extend(contents, M.split_lines(value))
            -- MarkupString variation 2
        elseif input.language then
            -- Some servers send input.value as empty, so let's ignore this :(
            -- assert(type(input.value) == 'string')
            table.insert(contents, "```" .. input.language)
            vim.list_extend(contents, M.split_lines(input.value or ""))
            table.insert(contents, "```")
            -- By deduction, this must be MarkedString[]
        else
            for _, marked_string in ipairs(input) do
                M.FormatHover(marked_string, contents)
            end
        end
        if (contents[1] == "" or contents[1] == nil) and #contents == 1 then
            return {}
        end
    end
    return contents
end

-- used for "fsharp/documentationSymbol" - accepts DocumentationForSymbolReuqest,
-- returns documentation data about given symbol from given assembly, used for InfoPanel
-- original fsharp type declaration :
-- type DocumentationForSymbolReuqest = { XmlSig: string; Assembly: string }
---@class FSharpDocumentationForSymbolRequest
---@field XmlSig string
---@field Assembly string

---Creates a DocumentationForSymbolRequest from the xmlSig and assembly strings
---@param xmlSig string
---@param assembly string
---@return FSharpDocumentationForSymbolRequest
function M.DocumentationForSymbolRequest(xmlSig, assembly)
    ---@type FSharpDocumentationForSymbolRequest
    local result = {
        XmlSig = xmlSig,
        Assembly = assembly,
    }
    return result
end

---determines if input string ends with the suffix given.
---@param s string
---@param suffix string
---@return boolean
function M.stringEndsWith(s, suffix)
    return s:sub(- #suffix) == suffix
end

return M
-- vim:et ts=2 sw=2
