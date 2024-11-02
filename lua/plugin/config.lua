local util = require("plugin.util")
local lsp = vim.lsp

local M = {}

---@type _.lspconfig.settings.fsautocomplete.FSharp
M.DefaultServerSettings = {

        -- `addFsiWatcher`,
        addFsiWatcher = false,
        -- `addPrivateAccessModifier`,
        addPrivateAccessModifier = false,
        -- `autoRevealInExplorer`,
        autoRevealInExplorer = "sameAsFileExplorer",
        -- `disableFailedProjectNotifications`,
        disableFailedProjectNotifications = false,
        -- `enableMSBuildProjectGraph`,
        enableMSBuildProjectGraph = true,
        -- `enableReferenceCodeLens`,
        enableReferenceCodeLens = true,
        -- `enableTouchBar`,
        enableTouchBar = true,
        -- `enableTreeView`,
        enableTreeView = true,
        -- `fsiSdkFilePath`,
        fsiSdkFilePath = "",
        -- `infoPanelReplaceHover`,
        --  Not relevant to Neovim, currently
        --  if there's a big demand I'll consider making one.
        infoPanelReplaceHover = false,
        -- `infoPanelShowOnStartup`,
        infoPanelShowOnStartup = false,
        -- `infoPanelStartLocked`,
        infoPanelStartLocked = false,
        -- `infoPanelUpdate`,
        infoPanelUpdate = "onCursorMove",
        -- `inlineValues`, https://github.com/ionide/ionide-vscode-fsharp/issues/1963   https://github.com/ionide/FsAutoComplete/issues/1214
        inlineValues = { enabled = false, prefix = "  // " },
        --includeAnalyzers
        includeAnalyzers = {},
        --excludeAnalyzers
        excludeAnalyzers = {},
        unnecessaryParenthesesAnalyzer = true,
        -- `msbuildAutoshow`,
        --  Not relevant to Neovim, currently
        msbuildAutoshow = false,
        -- `notifications`,
        notifications = { trace = false, traceNamespaces = { "BoundModel.TypeCheck", "BackgroundCompiler." } },
        -- `openTelemetry`,
        openTelemetry = { enabled = false },
        -- `pipelineHints`,
        pipelineHints = { enabled = true, prefix = "  // " },
        -- `saveOnSendLastSelection`,
        saveOnSendLastSelection = false,
        -- `showExplorerOnStartup`,
        --  Not relevant to Neovim, currently
        showExplorerOnStartup = false,
        -- `showProjectExplorerIn`,
        --  Not relevant to Neovim, currently
        showProjectExplorerIn = "fsharp",
        -- `simplifyNameAnalyzerExclusions`,
        --  Not relevant to Neovim, currently
        simplifyNameAnalyzerExclusions = { ".*\\.g\\.fs", ".*\\.cg\\.fs" },
        -- `smartIndent`,
        --  Not relevant to Neovim, currently
        smartIndent = true,
        -- `suggestGitignore`,
        suggestGitignore = true,
        -- `trace`,
        trace = { server = "off" },
        -- `unusedDeclarationsAnalyzerExclusions`,
        unusedDeclarationsAnalyzerExclusions = { ".*\\.g\\.fs", ".*\\.cg\\.fs" },
        -- `unusedOpensAnalyzerExclusions`,
        unusedOpensAnalyzerExclusions = { ".*\\.g\\.fs", ".*\\.cg\\.fs" },
        -- `verboseLogging`,
        verboseLogging = false,
        -- `workspacePath`
        workspacePath = "",
        -- `TestExplorer` = "",
        --  Not relevant to Neovim, currently
        TestExplorer = { AutoDiscoverTestsOnLoad = true },

        --   { AutomaticWorkspaceInit: bool option AutomaticWorkspaceInit = false
        --     WorkspaceModePeekDeepLevel: int option WorkspaceModePeekDeepLevel = 2
        workspaceModePeekDeepLevel = 4,
        fcs = { transparentCompiler = { enabled = true } },
        fsac = {
                attachDebugger = false,
                cachedTypeCheckCount = 200,
                conserveMemory = true,
                silencedLogs = {},
                parallelReferenceResolution = true,
                -- "FSharp.fsac.sourceTextImplementation": {
                --        "default": "NamedText",
                --    "description": "EXPERIMENTAL. Enables the use of a new source text implementation. This may have better memory characteristics. Requires restart.",
                --      "enum": [
                --        "NamedText",
                --        "RoslynSourceText"
                --      ]
                --    },
                sourceTextImplementation = "RoslynSourceText",
                dotnetArgs = {},
                netCoreDllPath = "",
                gc = {
                        conserveMemory = 0,
                        heapCount = 2,
                        noAffinitize = true,
                        server = true,
                },
        },

        enableAdaptiveLspServer = true,
        --     ExcludeProjectDirectories: string[] option = [||]
        excludeProjectDirectories = { "paket-files", ".fable", "packages", "node_modules" },
        --     KeywordsAutocomplete: bool option false
        keywordsAutocomplete = true,
        --     fullNameExternalAutocomplete: bool option false
        fullNameExternalAutocomplete = false,
        --     ExternalAutocomplete: bool option false
        externalAutocomplete = false,
        --     Linter: bool option false
        linter = true,
        --     IndentationSize: int option 4
        indentationSize = 2,
        --     UnionCaseStubGeneration: bool option false
        unionCaseStubGeneration = true,
        --     UnionCaseStubGenerationBody: string option """failwith "Not Implemented" """
        unionCaseStubGenerationBody = 'failwith "Not Implemented"',
        --     RecordStubGeneration: bool option false
        recordStubGeneration = true,
        --     RecordStubGenerationBody: string option "failwith \"Not Implemented\""
        recordStubGenerationBody = 'failwith "Not Implemented"',
        --     InterfaceStubGeneration: bool option false
        interfaceStubGeneration = true,
        --     InterfaceStubGenerationObjectIdentifier: string option "this"
        interfaceStubGenerationObjectIdentifier = "this",
        --     InterfaceStubGenerationMethodBody: string option "failwith \"Not Implemented\""
        interfaceStubGenerationMethodBody = 'failwith "Not Implemented"',
        --     UnusedOpensAnalyzer: bool option false
        unusedOpensAnalyzer = true,
        --     UnusedDeclarationsAnalyzer: bool option false
        unusedDeclarationsAnalyzer = true,
        --     SimplifyNameAnalyzer: bool option false
        simplifyNameAnalyzer = true,
        --     ResolveNamespaces: bool option false
        resolveNamespaces = true,
        --     EnableAnalyzers: bool option false
        enableAnalyzers = true,
        --     AnalyzersPath: string[] option
        analyzersPath = { "packages/Analyzers", "analyzers" },
        --     DisableInMemoryProjectReferences: bool option false|
        -- disableInMemoryProjectReferences = false,

        -- LineLens: LineLensConfig option
        lineLens = { enabled = "always", prefix = "ll//" },

        -- enables the use of .Net Core SDKs for script file type-checking and evaluation,
        -- otherwise the .Net Framework reference lists will be used.
        -- Recommended default value: `true`.
        --
        useSdkScripts = true,

        suggestSdkScripts = true,
        -- DotNetRoot - the path to the dotnet sdk. usually best left alone, the compiler searches for this on it's own,
        dotnetRoot = "",

        -- FSIExtraParameters: string[]
        -- an array of additional runtime arguments that are passed to FSI.
        -- These are used when typechecking scripts to ensure that typechecking has the same context as your FSI instances.
        -- An example would be to set the following parameters to enable Preview features (like opening static classes) for typechecking.
        -- defaults to {}
        fsiExtraParameters = {},

        -- FSICompilerToolLocations: string[]|nil
        -- passes along this list of locations to compiler tools for FSI to the FSharpCompilerServiceChecker
        -- to this function in fsautocomplete
        -- https://github.com/fsharp/FsAutoComplete/blob/main/src/FsAutoComplete/LspServers/AdaptiveFSharpLspServer.fs#L99
        -- which effectively just prepends "--compilertool:" to each entry and tells the FSharpCompilerServiceChecker about it and the fsiExtraParameters
        fsiCompilerToolLocations = {},

        -- TooltipMode: string option
        -- TooltipMode can be one of the following:
        -- "full" ->  this provides the most verbose output
        -- "summary" -> this is a slimmed down version of the tooltip
        -- "" or nil -> this is the old or default way, and calls TipFormatter.FormatCommentStyle.Legacy on the lsp server... *shrug*
        tooltipMode = "full",

        -- GenerateBinlog
        -- if true, binary logs will be generated and placed in the directory specified. They will have names of the form `{directory}/{project_name}.binlog`
        -- defaults to false
        generateBinlog = false,
        abstractClassStubGeneration = true,
        abstractClassStubGenerationObjectIdentifier = "this",
        abstractClassStubGenerationMethodBody = 'failwith "Not Implemented"',

        -- configures which parts of the CodeLens are enabled, if any
        -- defaults to both signature and references being true
        codeLenses = {
                signature = { enabled = true },
                references = { enabled = true },
        },

        --     InlayHints: InlayHintDto option
        --type InlayHintsConfig =
        -- { typeAnnotations: bool
        -- parameterNames: bool
        -- disableLongTooltip: bool }
        -- static member Default =
        --   { typeAnnotations = true
        --     parameterNames = true
        --     disableLongTooltip = true }
        inlayHints = {
                --do these really annoy anyone? why not have em on?
                enabled = true,
                typeAnnotations = true,
                -- Defaults to false, the more info the better, right?
                disableLongTooltip = false,
                parameterNames = true,
        },
        --     Debug: DebugDto option }
        --   type DebugConfig =
        -- { DontCheckRelatedFiles: bool
        --   CheckFileDebouncerTimeout: int
        --   LogDurationBetweenCheckFiles: bool
        --   LogCheckFileDuration: bool }
        --
        -- static member Default =
        --   { DontCheckRelatedFiles = false
        --     CheckFileDebouncerTimeout = 250
        --     LogDurationBetweenCheckFiles = false
        --     LogCheckFileDuration = false }
        --       }
        debug = {
                dontCheckRelatedFiles = false,
                checkFileDebouncerTimeout = 250,
                logDurationBetweenCheckFiles = false,
                logCheckFileDuration = false,
        },
}

---@type IonideNvimSettings
M.DefaultNvimSettings = {
        FsautocompleteCommand = {
                "fsautocomplete",
                "--adaptive-lsp-server-enabled",
                "--project-graph-enabled",
                "--use-fcs-transparent-compiler"
        },
        UseRecommendedServerConfig = false,
        -- we do it with sln
        AutomaticWorkspaceInit = false,
        AutomaticReloadWorkspace = true,
        AutomaticCodeLensRefresh = true,
        ShowSignatureOnCursorMove = true,
        FsiCommand = "dotnet fsi",
        FsiKeymap = "vscode",
        FsiWindowCommand = "botright 10new",
        FsiFocusOnSend = false,
        EnableFsiStdOutTeeToFile = false,
        LspAutoSetup = false,
        LspRecommendedColorScheme = false,
        FsiVscodeKeymaps = true,
        FsiStdOutFileName = "",
        StatusLine = "Ionide",
        AutocmdEvents = {
                "LspAttach",
                "BufEnter",
                "BufWritePost",
                "CursorHold",
                "CursorHoldI",
                "InsertEnter",
                "InsertLeave",
        },
        FsiKeymapSend = "<M-cr>",
        FsiKeymapToggle = "<M-@>",
}

function M.GitFirstRootDir(n)
        local root
        root = util.find_git_ancestor(n)
        root = root or util.root_pattern("*.sln")(n)
        root = root or util.root_pattern("*.fsproj")(n)
        root = root or util.root_pattern("*.fsx")(n)
        return root
end

function M.setupLspConfig(handlers, on_init)
        M.DefaultLspConfig.handlers = handlers
        M.DefaultLspConfig.on_init = on_init
end

---@type IonideOptions
M.DefaultLspConfig = {
        IonideNvimSettings = M.DefaultNvimSettings,
        filetypes = { "fsharp" },
        name = "ionide",
        cmd = M.DefaultNvimSettings.FsautocompleteCommand,
        -- cmd_env = M.DefaultNvimSettings.FsautocompleteCommand,
        autostart = true,
        handlers = nil,
        init_options = { AutomaticWorkspaceInit = M.DefaultNvimSettings.AutomaticWorkspaceInit },
        -- on_attach = function(client, bufnr)
        -- local isProjFile = vim.bo[bufnr].filetype == "fsharp_project"
        -- if isProjFile then
        --   if lspconfig_is_present then
        --     local lspconfig = require("lspconfig")
        --   end
        -- else
        --   return
        -- end

        -- end,
        -- on_new_config = M.Initialize,
        on_init = nil,
        settings = { FSharp = M.DefaultServerSettings },
        root_dir = M.GitFirstRootDir,
        log_level = lsp.protocol.MessageType.Warning,
        message_level = lsp.protocol.MessageType.Warning,
        capabilities = lsp.protocol.make_client_capabilities(),
}

---@type IonideOptions
M.PassedInConfig = { settings = { FSharp = {} } }

---@type IonideOptions
M.MergedConfig = {}

return M
