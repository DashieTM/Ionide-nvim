-- TODO make this work

function M.InitializeDefaultFsiKeymapSettings()
    if not config.MergedConfig.IonideNvimSettings.FsiKeymap then
        config.MergedConfig.IonideNvimSettings.FsiKeymap = "vscode"
    end
    if vim.fn.has("nvim") then
        if config.MergedConfig.IonideNvimSettings.FsiKeymap == "vscode" then
            config.MergedConfig.IonideNvimSettings.FsiKeymapSend = "<M-cr>"
            config.MergedConfig.IonideNvimSettings.FsiKeymapToggle = "<M-@>"
        elseif config.MergedConfig.IonideNvimSettings.FsiKeymap == "vim-fsharp" then
            config.MergedConfig.IonideNvimSettings.FsiKeymapSend = "<leader>i"
            config.MergedConfig.IonideNvimSettings.FsiKeymapToggle = "<leader>e"
        elseif config.MergedConfig.IonideNvimSettings.FsiKeymap == "custom" then
            config.MergedConfig.IonideNvimSettings.FsiKeymap = "none"
            if not config.MergedConfig.IonideNvimSettings.FsiKeymapSend then
                vim.cmd.echoerr(
                    "FsiKeymapSend not set. good luck with that I dont have a nice way to change it yet. sorry. ")
            elseif not config.MergedConfig.IonideNvimSettings.FsiKeymapToggle then
                vim.cmd.echoerr(
                    "FsiKeymapToggle not set. good luck with that I dont have a nice way to change it yet. sorry. ")
            else
                config.MergedConfig.IonideNvimSettings.FsiKeymap = "custom"
            end
        end
    else
        util.notify("I'm sorry I don't support regular vim, try ionide/ionide-vim instead")
    end
end

FsiBuffer = -1
local fsiJob = -1
local fsiWidth = 0
local fsiHeight = 0

uc("IonideResetIonideBufferNumber", function()
    FsiBuffer = -1
    vim.notify("Fsi buffer is now set to number " .. vim.inspect(FsiBuffer))
end, {
    desc =
    "Resets the current buffer that fsi is assigned to back to the invalid number -1, so that Ionide knows to recreate it.",
})
--"
--" function! s:win_gotoid_safe(winid)
--"     function! s:vimReturnFocus(window)
--"         call win_gotoid(a:window)
--"         redraw!
--"     endfunction
--"     if has('nvim')
--"         call win_gotoid(a:winid)
--"     else
--"         call timer_start(1, { -> s:vimReturnFocus(a:winid) })
--"     endif
--" endfunction
local function vimReturnFocus(window)
    vim.fn.win_gotoid(window)
    vim.cmd.redraw("!")
end

local function winGoToIdSafe(id)
    if vim.fn.has("nvim") then
        vim.fn.win_gotoid(id)
    else
        vim.fn.timer_start(1, function()
            vimReturnFocus(id)
        end, {})
    end
end

--"
--" function! s:get_fsi_command()
--"     let cmd = g:fsharp#fsi_command
--"     for prm in g:fsharp#fsi_extra_parameters
--"         let cmd = cmd . " " . prm
--"     endfor
--"     return cmd
--" endfunction

local function getFsiCommand()
    local cmd = "dotnet fsi"
    if config.MergedConfig.IonideNvimSettings and config.MergedConfig.IonideNvimSettings.FsiCommand then
        cmd = config.MergedConfig.IonideNvimSettings.FsiCommand or "dotnet fsi"
    end
    local ep = {}
    if
        config.MergedConfig.settings
        and config.MergedConfig.settings.FSharp
        and config.MergedConfig.settings.FSharp.fsiExtraParameters
    then
        ep = config.MergedConfig.settings.FSharp.fsiExtraParameters or {}
    end
    if #ep > 0 then
        cmd = cmd .. " " .. vim.fn.join(ep, " ")
    end
    if
        config.MergedConfig.IonideNvimSettings
        and config.MergedConfig.IonideNvimSettings.EnableFsiStdOutTeeToFile
        and config.MergedConfig.IonideNvimSettings.EnableFsiStdOutTeeToFile == true
    then
        local teeToInvoke = " *>&1 | tee '"
        local teeToTry = [[
$Path = "$pshome\types.ps1xml";
[IO.StreamReader]$reader = [System.IO.StreamReader]::new($Path)
# embed loop in scriptblock:
& {
    while (-not $reader.EndOfStream)
    {
        # read current line
        $reader.ReadLine()

        # add artificial delay to pretend this was a HUGE file
        Start-Sleep -Milliseconds 10
    }
# process results in real-time as they become available:
} | Out-GridView

# close and dispose the streamreader properly:
$reader.Close()
$reader.Dispose()

    ]]
        -- local teeToInvoke = [[ | ForEach-Object { tee $_ $_ } | tee ']]
        local defaultOutputName = "./fsiOutputFile.txt"
        if config.MergedConfig.IonideNvimSettings and config.MergedConfig.IonideNvimSettings.FsiStdOutFileName then
            if config.MergedConfig.IonideNvimSettings.FsiStdOutFileName ~= "" then
                cmd = cmd ..
                    teeToInvoke ..
                    (config.MergedConfig.IonideNvimSettings.FsiStdOutFileName or defaultOutputName) .. "'"
            else
                cmd = cmd .. teeToInvoke .. defaultOutputName .. "'"
            end
        end
    end

    return cmd
end

local function getFsiWindowCommand()
    local cmd = "botright 10new"
    if config.MergedConfig.IonideNvimSettings and config.MergedConfig.IonideNvimSettings.FsiWindowCommand then
        cmd = config.MergedConfig.IonideNvimSettings.FsiWindowCommand or "botright 10new"
    end
    return cmd
end

function M.OpenFsi(returnFocus)
    if vim.fn.bufwinid(FsiBuffer) <= 0 then
        local cmd = getFsiCommand()
        local currentWin = vim.fn.win_getid()
        vim.fn.execute(getFsiWindowCommand())
        if fsiWidth > 0 then
            vim.fn.execute("vertical resize " .. fsiWidth)
        end
        if fsiHeight > 0 then
            vim.fn.execute("resize " .. fsiHeight)
        end
        if FsiBuffer >= 0 and vim.fn.bufexists(FsiBuffer) == 1 then
            vim.cmd.b(string.format("%i", FsiBuffer))
            vim.cmd.normal("G")
            if returnFocus then
                winGoToIdSafe(currentWin)
            end
        else
            fsiJob = vim.fn.termopen(cmd) or 0
            if fsiJob > 0 then
                FsiBuffer = vim.fn.bufnr(vim.api.nvim_get_current_buf())
            else
                vim.cmd.close()
                util.notify("failed to open FSI")
                return -1
            end
        end
        vim.opt_local.bufhidden = "hide"
        vim.cmd.normal("G")
        if returnFocus then
            winGoToIdSafe(currentWin)
        end
        return FsiBuffer
    end
    return FsiBuffer
end

-- function M.OpenFsi(returnFocus)
--   util.notify("OpenFsi got return focus as " .. vim.inspect(returnFocus))
--   local isNeovim = vim.fn.has('nvim')
--   if not isNeovim then
--     util.notify("This version of ionide is for Neovim only. please try www.github.com/ionide/ionide-vim")
--   end
--     if vim.fn.exists('*termopen') == true or vim.fn.exists('*term_start') then
--       --"             let current_win = win_getid()
--       local currentWin = vim.fn.win_getid()
--     util.notify("OpenFsi currentWin = " .. vim.inspect(currentWin))
--       --"             execute g:fsharp#fsi_window_command
--       vim.fn.execute(M.FsiWindowCommand or 'botright 10new')
--       -- "             if s:fsi_width  > 0 | execute 'vertical resize' s:fsi_width | endif
--       if fsiWidth > 0 then vim.fn.execute('vertical resize ' .. fsiWidth) end
--       --"             if s:fsi_height > 0 | execute 'resize' s:fsi_height | endif
--       if fsiHeight > 0 then vim.fn.execute('resize ' .. fsiHeight) end
--       --"             " if window is closed but FSI is still alive then reuse it
--       --"             if s:fsi_buffer >= 0 && bufexists(str2nr(s:fsi_buffer))
--       if FsiBuffer >= 0 and vim.fn.bufexists(FsiBuffer) then
--         --"                 exec 'b' s:fsi_buffer
--         vim.cmd('b' .. tostring(FsiBuffer))
--         --"                 normal G
--
--         vim.cmd("normal G")
--         --"                 if a:returnFocus | call s:win_gotoid_safe(current_win) | endif
--         if returnFocus then winGoToIdSafe(currentWin) end
--         --"             " open FSI: Neovim
--         --"             elseif has('nvim')
--   local bufWinid = vim.fn.bufwinid(FsiBuffer) or -1
--   util.notify("OpenFsi bufWinid = " .. vim.inspect(bufWinid))
--   if bufWinid <= 0 then
--     local cmd = getFsiCommand()
--     if isNeovim then
--       fsiJob = vim.fn.termopen(cmd)
--       util.notify("OpenFsi fsiJob is now  = " .. vim.inspect(fsiJob))
--       if fsiJob > 0 then
--         FsiBuffer = vim.fn.bufnr(vim.api.nvim_get_current_buf())
--       else
--         vim.cmd.close()
--         util.notify("failed to open FSI")
--         return -1
--       end
--     end
--   end
--   util.notify("This version of ionide is for Neovim only. please try www.github.com/ionide/ionide-vim")
--   if returnFocus then winGoToIdSafe(currentWin) end
--   return FsiBuffer
-- end
--
--"
--" function! fsharp#toggleFsi()
--"     let fsiWindowId = bufwinid(s:fsi_buffer)
--"     if fsiWindowId > 0
--"         let current_win = win_getid()
--"         call win_gotoid(fsiWindowId)
--"         let s:fsi_width = winwidth('%')
--"         let s:fsi_height = winheight('%')
--"         close
--"         call win_gotoid(current_win)
--"     else
--"         call fsharp#openFsi(0)
--"     endif
--" endfunction

function M.ToggleFsi()
    local w = vim.fn.bufwinid(FsiBuffer)
    if w > 0 then
        local curWin = vim.fn.win_getid()
        M.winGoToId(w)
        fsiWidth = vim.fn.winwidth(tonumber(vim.fn.expand("%")) or 0)
        fsiHeight = vim.fn.winheight(tonumber(vim.fn.expand("%")) or 0)
        vim.cmd.close()
        vim.fn.win_gotoid(curWin)
    else
        M.OpenFsi()
    end
end

function M.GetVisualSelection(keepSelectionIfNotInBlockMode, advanceCursorOneLine, debugNotify)
    local line_start, column_start
    local line_end, column_end
    -- if debugNotify is true, use util.notify to show debug info.
    debugNotify = debugNotify or false
    -- keep selection defaults to false, but if true the selection will
    -- be reinstated after it's cleared to set '> and '<
    -- only relevant in visual or visual line mode, block always keeps selection.
    keepSelectionIfNotInBlockMode = keepSelectionIfNotInBlockMode or false
    -- advance cursor one line defaults to true, but is turned off for
    -- visual block mode regardless.
    advanceCursorOneLine = (function()
        if keepSelectionIfNotInBlockMode == true then
            return false
        else
            return advanceCursorOneLine or true
        end
    end)()

    if vim.fn.visualmode() == "\22" then
        line_start, column_start = unpack(vim.fn.getpos("v"), 2)
        line_end, column_end = unpack(vim.fn.getpos("."), 2)
    else
        -- if not in visual block mode then i want to escape to normal mode.
        -- if this isn't done here, then the '< and '> do not get set,
        -- and the selection will only be whatever was LAST selected.
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
        line_start, column_start = unpack(vim.fn.getpos("'<"), 2)
        line_end, column_end = unpack(vim.fn.getpos("'>"), 2)
    end
    if column_start > column_end then
        column_start, column_end = column_end, column_start
        if debugNotify == true then
            util.notify(
                "switching column start and end, \nWas "
                .. column_end
                .. ","
                .. column_start
                .. "\nNow "
                .. column_start
                .. ","
                .. column_end
            )
        end
    end
    if line_start > line_end then
        line_start, line_end = line_end, line_start
        if debugNotify == true then
            util.notify(
                "switching line start and end, \nWas "
                .. line_end
                .. ","
                .. line_start
                .. "\nNow "
                .. line_start
                .. ","
                .. line_end
            )
        end
    end
    if vim.g.selection == "exclusive" then
        column_end = column_end - 1 -- Needed to remove the last character to make it match the visual selection
    end
    if debugNotify == true then
        util.notify(
            "vim.fn.visualmode(): "
            .. vim.fn.visualmode()
            .. "\nsel start "
            .. vim.inspect(line_start)
            .. " "
            .. vim.inspect(column_start)
            .. "\nSel end "
            .. vim.inspect(line_end)
            .. " "
            .. vim.inspect(column_end)
        )
    end
    local n_lines = math.abs(line_end - line_start) + 1
    local lines = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)
    if #lines == 0 then
        return { "" }
    end
    if vim.fn.visualmode() == "\22" then
        -- this is what actually sets the lines to only what is found between start and end columns
        for i = 1, #lines do
            lines[i] = string.sub(lines[i], column_start, column_end)
        end
    else
        lines[1] = string.sub(lines[1], column_start, -1)
        if n_lines == 1 then
            lines[n_lines] = string.sub(lines[n_lines], 1, column_end - column_start + 1)
        else
            lines[n_lines] = string.sub(lines[n_lines], 1, column_end)
        end
        -- if advanceCursorOneLine == true, then i do want the cursor to advance once.
        if advanceCursorOneLine == true then
            if debugNotify == true then
                util.notify("advancing cursor one line past the end of the selection to line " ..
                    vim.inspect(line_end + 1))
            end

            local lastline = vim.fn.line("w$")
            if line_end > lastline then
                vim.api.nvim_win_set_cursor(0, { line_end + 1, 0 })
            end
        end

        if keepSelectionIfNotInBlockMode then
            vim.api.nvim_feedkeys("gv", "n", true)
        end
    end
    if debugNotify == true then
        util.notify(vim.fn.join(lines, "\n") .. "\n")
        -- util.notify(table.concat(lines, "\n"))
    end
    return lines -- use this return if you want an array of text lines
    -- return table.concat(lines, "\n") -- use this return instead if you need a text block
end

--"
--" function! fsharp#quitFsi()
--"     if s:fsi_buffer >= 0 && bufexists(str2nr(s:fsi_buffer))
--"         if has('nvim')
--"             let winid = bufwinid(s:fsi_buffer)
--"             if winid > 0 | execute "close " . winid | endif
--"             call jobstop(s:fsi_job)
--"         else
--"             call job_stop(s:fsi_job, "term")
--"         endif
--"         let s:fsi_buffer = -1
--"         let s:fsi_job = -1
--"     endif
--" endfunction
--

---Quit current fsi
function M.QuitFsi()
    if vim.api.nvim_buf_is_valid(FsiBuffer) then
        local winid = vim.api.nvim_call_function("bufwinid", { FsiBuffer })
        if winid > 0 then
            vim.api.nvim_win_close(winid, true)
        end
        vim.api.nvim_call_function("jobstop", { fsiJob })
        FsiBuffer = -1
        fsiJob = -1
    end
end

--" function! fsharp#resetFsi()
--"     call fsharp#quitFsi()
--"     return fsharp#openFsi(1)
--" endfunction
--"
function M.ResetFsi()
    M.QuitFsi()
    M.OpenFsi(false)
end

--" function! fsharp#sendFsi(text)
--"     if fsharp#openFsi(!g:fsharp#fsi_focus_on_send) > 0
--"         " Neovim
--"         if has('nvim')
--"             call chansend(s:fsi_job, a:text . "\n" . ";;". "\n")
--"         " Vim 8
--"         else
--"             call term_sendkeys(s:fsi_buffer, a:text . "\<cr>" . ";;" . "\<cr>")
--"             call term_wait(s:fsi_buffer)
--"         endif
--"     endif
--" endfunction
-- "

---sends lines to FSI
---@param lines string[]
function M.SendFsi(lines)
    local focusOnSend = false
    if config.MergedConfig.IonideNvimSettings and config.MergedConfig.IonideNvimSettings.FsiFocusOnSend then
        focusOnSend = config.MergedConfig.IonideNvimSettings.FsiFocusOnSend or false
    end
    local openResult = M.OpenFsi(focusOnSend)
    if not openResult then
        openResult = 1
    end

    if openResult > 0 then
        local toBeSent = vim.list_extend(lines, { "", ";;", "" })
        -- util.notify("Text being sent to FSI:\n" .. vim.inspect(toBeSent))
        vim.fn.chansend(fsiJob, toBeSent)
    end
end

function M.GetCompleteBuffer()
    return vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 1, -1, false)
end

function M.SendSelectionToFsi()
    -- vim.cmd(':normal' .. vim.fn.len(lines) .. 'j')
    local lines = M.GetVisualSelection()

    -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), 'x', true)
    -- vim.cmd(':normal' .. ' j')
    -- vim.cmd('normal' .. vim.fn.len(lines) .. 'j')
    -- local text = vim.fn.join(lines, "\n")
    -- util.notify("fsi send selection " .. text)
    M.SendFsi(lines)

    -- local line_end, _ = unpack(vim.fn.getpos("'>"), 2)

    -- vim.cmd 'normal j'

    -- vim.cmd(':normal' .. ' j')
    -- vim.api.nvim_win_set_cursor(0, { line_end + 1, 0 })

    -- vim.cmd(':normal' .. vim.fn.len(lines) .. 'j')
end

function M.SendLineToFsi()
    local text = vim.api.nvim_get_current_line()
    local line, _ = unpack(vim.fn.getpos("."), 2)
    local lastline = vim.fn.line("w$")
    if line > lastline then
        vim.api.nvim_win_set_cursor(0, { line + 1, 0 })
    end
    -- util.notify("fsi send line " .. text)
    M.SendFsi({ text })
    -- vim.cmd 'normal j'
end

function M.SendAllToFsi()
    -- util.notify("fsi send all ")
    local text = M.GetCompleteBuffer()
    return M.SendFsi(text)
end

function M.SetKeymaps()
    local send = config.MergedConfig.IonideNvimSettings.FsiKeymapSend or "<M-CR>"
    local toggle = config.MergedConfig.IonideNvimSettings.FsiKeymapToggle or "<M-@>"
    vim.keymap.set("v", send, function()
        M.SendSelectionToFsi()
    end, { silent = false })
    vim.keymap.set("n", send, function()
        M.SendLineToFsi()
    end, { silent = false })
    vim.keymap.set("n", toggle, function()
        M.ToggleFsi()
    end, { silent = false })
    vim.keymap.set("t", toggle, function()
        M.ToggleFsi()
    end, { silent = false })
end
