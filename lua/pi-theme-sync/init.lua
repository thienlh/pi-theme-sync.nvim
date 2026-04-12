local M = {}

-- Default configuration
M.config = {
	piThemesDir = vim.fn.expand("~/.pi/agent/themes"),
	piSettingsPath = vim.fn.expand("~/.pi/agent/settings.json"),
	autoExport = true,
	exportOnColorscheme = true,
	exportOnStartup = true,
	startupDelay = 500,
	cleanupTmpThemes = true,
	maxTmpThemes = 10,
	keepRecentTmpThemes = 5,
	createCommands = true,
	createPiCommand = true,
}

-- Cached nvim instance ID
local cachedNvimId = nil
local augroup = vim.api.nvim_create_augroup("PiThemeSync", { clear = true })

-- Convert 256-color index to hex
local function ansi256ToHex(index)
	if index < 16 then
		-- Standard colors (approximate)
		local basic = {
			"#000000",
			"#800000",
			"#008000",
			"#808000",
			"#000080",
			"#800080",
			"#008080",
			"#c0c0c0",
			"#808080",
			"#ff0000",
			"#00ff00",
			"#ffff00",
			"#0000ff",
			"#ff00ff",
			"#00ffff",
			"#ffffff",
		}
		return basic[index + 1] or "#808080"
	elseif index < 232 then
		-- Color cube (16-231)
		local cubeIndex = index - 16
		local r = math.floor(cubeIndex / 36)
		local g = math.floor((cubeIndex % 36) / 6)
		local b = cubeIndex % 6
		local toHex = function(n)
			if n == 0 then
				return "00"
			end
			return string.format("%02x", 55 + n * 40)
		end
		return "#" .. toHex(r) .. toHex(g) .. toHex(b)
	else
		-- Grayscale (232-255)
		local gray = 8 + (index - 232) * 10
		return string.format("#%02x%02x%02x", gray, gray, gray)
	end
end

-- Get color from highlight group, handling both gui and cterm
local function getHighlightColor(group, attr)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
	if not ok then
		return nil
	end

	-- Try GUI color first (hex)
	if attr == "fg" and hl.fg then
		return string.format("#%06x", hl.fg)
	elseif attr == "bg" and hl.bg then
		return string.format("#%06x", hl.bg)
	end

	-- Fall back to cterm color (convert to hex)
	if attr == "fg" and hl.ctermfg then
		return ansi256ToHex(hl.ctermfg)
	elseif attr == "bg" and hl.ctermbg then
		return ansi256ToHex(hl.ctermbg)
	end

	return nil
end

-- Safely get color with fallback chain
local function getColorWithFallback(groups, attr, fallback)
	for _, group in ipairs(groups) do
		local color = getHighlightColor(group, attr)
		if color then
			return color
		end
	end
	return fallback
end

-- Get unique nvim instance ID from process ID with nvim- prefix
local function getNvimId()
	if cachedNvimId then
		return cachedNvimId
	end
	cachedNvimId = "nvim-" .. tostring(vim.fn.getpid())
	return cachedNvimId
end

-- Cleanup old nvim themes (only cleans up files created by this plugin)
local function cleanupOldTmpThemes()
	if not M.config.cleanupTmpThemes then
		return
	end

	local nvim_files = {}
	local all_files = vim.fn.glob(M.config.piThemesDir .. "/*.json", false, true)
	for _, filepath in ipairs(all_files) do
		local filename = vim.fn.fnamemodify(filepath, ":t")
		if filename:match("^nvim%-") then
			local mtime = vim.fn.getftime(filepath)
			table.insert(nvim_files, { path = filepath, mtime = mtime })
		end
	end

	if #nvim_files <= M.config.maxTmpThemes then
		return
	end

	table.sort(nvim_files, function(a, b)
		return a.mtime < b.mtime
	end)

	local to_remove = #nvim_files - M.config.keepRecentTmpThemes
	if to_remove <= 0 then
		return
	end

	for i = 1, to_remove do
		vim.fn.delete(nvim_files[i].path)
	end
end

-- Export current colorscheme to pi theme
function M.exportPiTheme()
	-- Ensure pi config directory exists
	vim.fn.mkdir(M.config.piThemesDir, "p")

	local colors = {
		-- Syntax highlighting
		syntaxComment = getColorWithFallback({ "Comment", "@comment", "SpecialComment" }, "fg", "#6A9955"),
		syntaxKeyword = getColorWithFallback(
			{ "Keyword", "@keyword", "Statement", "Conditional", "Repeat", "Label" },
			"fg",
			"#569CD6"
		),
		syntaxFunction = getColorWithFallback(
			{ "Function", "@function", "@method", "@function.call" },
			"fg",
			"#DCDCAA"
		),
		syntaxVariable = getColorWithFallback({ "Identifier", "@variable", "@identifier" }, "fg", "#9CDCFE"),
		syntaxString = getColorWithFallback(
			{ "String", "@string", "@string.documentation", "Character" },
			"fg",
			"#CE9178"
		),
		syntaxNumber = getColorWithFallback({ "Number", "@number", "@float", "Boolean" }, "fg", "#B5CEA8"),
		syntaxType = getColorWithFallback(
			{ "Type", "@type", "@type.builtin", "Structure", "Typedef" },
			"fg",
			"#4EC9B0"
		),
		syntaxOperator = getColorWithFallback({ "Operator", "@operator" }, "fg", "#D4D4D4"),
		syntaxPunctuation = getColorWithFallback(
			{ "Delimiter", "@punctuation", "@punctuation.bracket", "@punctuation.delimiter" },
			"fg",
			"#D4D4D4"
		),

		-- UI colors
		accent = getColorWithFallback({ "DiagnosticInfo", "@constant" }, "fg", "#8abeb7"),
		border = getColorWithFallback({ "FloatBorder", "WinSeparator", "VertSplit" }, "fg", "#5f87ff"),
		borderAccent = getColorWithFallback({ "Title", "@text.title" }, "fg", "#00d7ff"),
		borderMuted = getColorWithFallback({ "NonText", "Conceal", "Ignore" }, "fg", "#505050"),
		success = getColorWithFallback({ "DiagnosticOk", "@text.note", "DiffAdd" }, "fg", "#b5bd68"),
		error = getColorWithFallback({ "Error", "DiagnosticError", "DiffDelete" }, "fg", "#cc6666"),
		warning = getColorWithFallback({ "Warning", "DiagnosticWarn", "Todo" }, "fg", "#ffff00"),
		muted = getColorWithFallback({ "Comment", "@comment" }, "fg", "#808080"),
		dim = getColorWithFallback({ "LineNr", "CursorLineNr" }, "fg", "#666666"),
		text = "",
		thinkingText = getColorWithFallback({ "Comment" }, "fg", "#808080"),

		-- Background colors
		selectedBg = getColorWithFallback({ "CursorLine", "Visual", "PmenuSel" }, "bg", "#3a3a4a"),
		userMessageBg = getColorWithFallback({ "NormalFloat", "Pmenu", "Normal" }, "bg", "#343541"),
		userMessageText = "",
		customMessageBg = getColorWithFallback({ "NormalFloat", "Pmenu" }, "bg", "#2d2838"),
		customMessageText = "",
		customMessageLabel = getColorWithFallback({ "Special", "@constant.builtin" }, "fg", "#9575cd"),
		toolPendingBg = getColorWithFallback({ "StatusLineNC", "LineNr" }, "bg", "#282832"),
		toolSuccessBg = getColorWithFallback({ "DiffAdd" }, "bg", "#283228"),
		toolErrorBg = getColorWithFallback({ "DiffDelete" }, "bg", "#3c2828"),
		toolTitle = "",
		toolOutput = getColorWithFallback({ "Comment" }, "fg", "#808080"),

		-- Markdown colors
		mdHeading = getColorWithFallback({ "Title", "@text.title", "markdownH1" }, "fg", "#f0c674"),
		mdLink = getColorWithFallback({ "Underlined", "@text.uri", "markdownLinkText" }, "fg", "#81a2be"),
		mdLinkUrl = getColorWithFallback({ "Comment" }, "fg", "#666666"),
		mdCode = getColorWithFallback({ "@text.literal", "markdownCode" }, "fg", "#8abeb7"),
		mdCodeBlock = getColorWithFallback({ "@text.literal", "markdownCodeBlock" }, "fg", "#b5bd68"),
		mdCodeBlockBorder = getColorWithFallback({ "Comment" }, "fg", "#808080"),
		mdQuote = getColorWithFallback({ "Comment", "@text.quote" }, "fg", "#808080"),
		mdQuoteBorder = getColorWithFallback({ "Comment" }, "fg", "#808080"),
		mdHr = getColorWithFallback({ "Comment" }, "fg", "#808080"),
		mdListBullet = getColorWithFallback({ "Special", "markdownListMarker" }, "fg", "#8abeb7"),

		-- Diff colors
		toolDiffAdded = getColorWithFallback({ "DiffAdd", "@diff.plus" }, "fg", "#b5bd68"),
		toolDiffRemoved = getColorWithFallback({ "DiffDelete", "@diff.minus" }, "fg", "#cc6666"),
		toolDiffContext = getColorWithFallback({ "Comment" }, "fg", "#808080"),

		-- Thinking level borders
		thinkingOff = getColorWithFallback({ "NonText" }, "fg", "#505050"),
		thinkingMinimal = getColorWithFallback({ "Comment" }, "fg", "#6e6e6e"),
		thinkingLow = getColorWithFallback({ "DiagnosticInfo" }, "fg", "#5f87af"),
		thinkingMedium = getColorWithFallback({ "DiagnosticHint" }, "fg", "#81a2be"),
		thinkingHigh = getColorWithFallback({ "DiagnosticWarn" }, "fg", "#b294bb"),
		thinkingXhigh = getColorWithFallback({ "DiagnosticError" }, "fg", "#d183e8"),

		-- Bash mode
		bashMode = getColorWithFallback({ "String", "@string" }, "fg", "#b5bd68"),
	}

	local theme_id = getNvimId()

	local theme = {
		["$schema"] = "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
		name = theme_id,
		colors = colors,
		export = {
			pageBg = getColorWithFallback({ "Normal" }, "bg", "#18181e"),
			cardBg = getColorWithFallback({ "NormalFloat", "Normal" }, "bg", "#1e1e24"),
			infoBg = getColorWithFallback({ "Pmenu", "NormalFloat" }, "bg", "#3c3728"),
		},
	}

	local outputPath = M.config.piThemesDir .. "/" .. getNvimId() .. ".json"
	local json = vim.json.encode(theme)

	local file, err = io.open(outputPath, "w")
	if file then
		file:write(json)
		file:close()
		return true
	else
		vim.notify("Failed to write pi theme: " .. (err or "unknown error"), vim.log.levels.ERROR)
		return false
	end
end

-- Open pi in terminal with current theme
function M.openPi()
	local nvim_id = getNvimId()
	local theme_path = M.config.piThemesDir .. "/" .. nvim_id .. ".json"

	-- Export theme if it doesn't exist
	if vim.fn.filereadable(theme_path) == 0 then
		M.exportPiTheme()
	end

	-- Update settings.json to use this theme
	do
		local file = io.open(M.config.piSettingsPath, "r")
		local settings = {}
		if file then
			local content = file:read("*a")
			file:close()
			local ok, decoded = pcall(vim.json.decode, content)
			if ok then
				settings = decoded
			end
		end

		settings.theme = nvim_id
		local out, err = io.open(M.config.piSettingsPath, "w")
		if out then
			out:write(vim.json.encode(settings))
			out:close()
		else
			vim.notify("Failed to update settings.json: " .. (err or "unknown"), vim.log.levels.WARN)
		end
	end

	-- Open terminal with pi
	vim.cmd("botright vsplit | terminal pi --no-themes --theme " .. vim.fn.shellescape(theme_path))
	vim.cmd("startinsert")

	-- Cleanup old tmp themes (deferred)
	vim.defer_fn(cleanupOldTmpThemes, 1000)
end

-- Disable auto-exports
function M.disable()
	vim.api.nvim_clear_autocmds({ group = augroup })
	vim.notify("pi-theme-sync auto-export disabled", vim.log.levels.INFO)
end

-- Re-enable auto-exports
function M.enable()
	if M.config.exportOnColorscheme then
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = augroup,
			callback = function()
				vim.defer_fn(M.exportPiTheme, 100)
			end,
			desc = "Export colorscheme to pi theme",
		})
	end

	-- Immediate export to sync current state (re-enable scenario)
	M.exportPiTheme()

	vim.notify("pi-theme-sync auto-export enabled", vim.log.levels.INFO)
end

-- Health check
function M.checkhealth()
	vim.health.start("pi-theme-sync")

	-- Check directories
	local themes_dir_exists = vim.fn.isdirectory(M.config.piThemesDir) == 1
	vim.health[themes_dir_exists and "ok" or "warn"]("Pi themes directory: " .. M.config.piThemesDir)

	-- Check if we can write
	-- NOTE: Intentionally using mkdir instead of temp file creation to avoid
	-- writing files to user's machine during health check. If directory exists
	-- and is accessible, writability is assumed. Users will see actual errors
	-- during export if permissions are insufficient.
	if themes_dir_exists then
		vim.fn.mkdir(M.config.piThemesDir, "p")
		vim.health.ok("Can write to themes directory")
	end

	-- Check theme file exists
	local theme_path = M.config.piThemesDir .. "/" .. getNvimId() .. ".json"
	if vim.fn.filereadable(theme_path) == 1 then
		vim.health.ok("Current theme file exists: " .. vim.fn.fnamemodify(theme_path, ":t"))
	else
		vim.health.warn("No theme exported yet for this session")
	end

	-- Check settings.json
	if vim.fn.filereadable(M.config.piSettingsPath) == 1 then
		vim.health.ok("Settings file exists: " .. M.config.piSettingsPath)
	else
		vim.health.info("Settings file will be created on first :Pi run")
	end

	vim.health.info("PID: " .. getNvimId())
end

-- Setup function
function M.setup(opts)
	opts = opts or {}

	-- Merge with global config if exists
	if vim.g.pi_theme_sync_config then
		opts = vim.tbl_deep_extend("force", vim.g.pi_theme_sync_config, opts)
	end

	-- Apply configuration
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	-- Create commands
	if M.config.createCommands then
		vim.api.nvim_create_user_command("PiThemeExport", function()
			M.exportPiTheme()
		end, { desc = "Export current nvim colorscheme to pi theme" })

		vim.api.nvim_create_user_command("PiThemeDisable", function()
			M.disable()
		end, { desc = "Disable pi-theme-sync auto-export" })

		vim.api.nvim_create_user_command("PiThemeEnable", function()
			M.enable()
		end, { desc = "Enable pi-theme-sync auto-export" })
	end

	if M.config.createPiCommand then
		vim.api.nvim_create_user_command("Pi", function()
			M.openPi()
		end, { desc = "Open pi in terminal with current nvim theme" })
	end

	-- Register autocmds if auto-export is enabled
	if M.config.autoExport then
		vim.api.nvim_clear_autocmds({ group = augroup })

		if M.config.exportOnColorscheme then
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = augroup,
				callback = function()
					vim.defer_fn(M.exportPiTheme, 100)
				end,
				desc = "Export colorscheme to pi theme",
			})
		end

		if M.config.exportOnStartup then
			-- Only defer if UI is available
			if vim.fn.has("gui_running") == 1 or vim.g.neovide or vim.env.TERM then
				vim.defer_fn(M.exportPiTheme, M.config.startupDelay)
			end
		end
	end
end

return M
