# pi-theme-sync.nvim

> :warning: **Very much work in progress** — built entirely through vibe coding. Expect rough edges, rapid changes, and experimental features. Contributions are welcomed.

![Demo](assets/demo.gif)

Sync your Neovim colorscheme to [pi](https://github.com/badlogic/pi-mono)'s theme system. This plugin automatically exports your current nvim colors so pi can match your editor's theme.

## Features

- Automatic theme export on startup and when colorscheme changes
- Creates a unique theme per nvim instance (PID-based)
- `:Pi` command to launch pi in a terminal split with matching theme
- Automatic cleanup of old temporary themes
- Health check support (`:checkhealth pi-theme-sync`)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "thienlh/pi-theme-sync.nvim",
  config = function()
    require("pi-theme-sync").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "thienlh/pi-theme-sync.nvim",
  config = function()
    require("pi-theme-sync").setup()
  end,
}
```

## Configuration

### Default configuration

```lua
require("pi-theme-sync").setup({
  -- Directory where pi looks for themes
  piThemesDir = vim.fn.expand("~/.pi/agent/themes"),

  -- Path to pi's settings.json
  piSettingsPath = vim.fn.expand("~/.pi/agent/settings.json"),

  -- Enable automatic theme export
  autoExport = true,

  -- Export when colorscheme changes
  exportOnColorscheme = true,

  -- Export on startup (with delay)
  exportOnStartup = true,
  startupDelay = 500, -- milliseconds

  -- Cleanup old nvim-* theme files
  cleanupTmpThemes = true,
  maxTmpThemes = 10,      -- Start cleanup when more than this exist
  keepRecentTmpThemes = 5, -- Keep this many most recent themes

  -- Create user commands
  createCommands = true,  -- :PiThemeExport, :PiThemeDisable, :PiThemeEnable
  createPiCommand = true, -- :Pi (launch pi in terminal)

  -- Width of the pi panel when opened with :Pi
  piWidth = 72,           -- Columns (default: 72, use 50-60 for 1/3 split on typical screens)
})
```

### Zero-config setup

Set global config before plugin loads:

```lua
-- In your init.lua, before loading plugins
vim.g.pi_theme_sync_config = {
  autoExport = true,
  cleanupTmpThemes = true,
}

-- Then in lazy.nvim, you don't need a config function:
{ "thienlh/pi-theme-sync.nvim" }
```

## Commands

| Command           | Description                                             |
| ----------------- | ------------------------------------------------------- |
| `:Pi`             | Open pi in a vertical split terminal with current theme |
| `:PiThemeExport`  | Manually export current colorscheme to pi               |
| `:PiThemeDisable` | Disable auto-export on colorscheme changes              |
| `:PiThemeEnable`  | Re-enable auto-export                                   |

## Recommended Keymap

Add this optional keymap to your `init.lua` (or keymaps configuration file) for quick access to pi:

```lua
vim.keymap.set("n", "<leader>ap", ":Pi<CR>", { desc = "Open Pi coding agent" })
```

## API

```lua
local pi_theme_sync = require("pi-theme-sync")

-- Export theme manually
pi_theme_sync.exportPiTheme()

-- Open pi
pi_theme_sync.openPi()

-- Disable/enable auto-export
pi_theme_sync.disable()
pi_theme_sync.enable()

-- Reconfigure
pi_theme_sync.setup({
  autoExport = false,
})
```

## Health Check

Run `:checkhealth pi-theme-sync` to verify:

- Themes directory exists and is writable
- Current theme file exists
- Settings file status

## How It Works

1. On startup or colorscheme change, the plugin extracts colors from your nvim highlight groups
2. Creates a JSON theme file in `~/.pi/agent/themes/nvim-<pid>.json`
3. Updates `~/.pi/agent/settings.json` to use this theme when you run `:Pi`
4. Cleans up old temporary themes automatically

## License

MIT
