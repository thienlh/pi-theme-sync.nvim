# Agent Guidelines

## Project Overview

This is a Neovim plugin that synchronizes the editor's colorscheme
with [pi](https://github.com/mariozechner/pi) (AI coding agent).

### Key Files

- `lua/pi-theme-sync/init.lua` - Main plugin logic, color extraction, theme export
- `lua/pi-theme-sync/health.lua` - Health check implementation
- `plugin/pi-theme-sync.lua` - Plugin setup and user commands
- `README.md` - User documentation

### Architecture Notes

- Plugin uses Neovim's highlight groups to extract colors from the active colorscheme
- Exports JSON theme files to pi's configuration directory

### Code Style

- Use snake_case for variables and functions
- Prefix internal functions with underscore when appropriate
- Add comments for non-obvious logic (e.g., empty string color values)
- Follow Lua conventions for Neovim plugins

## Common Tasks

### Adding New Color Mappings

When adding new color fields to the exported theme:

1. Use `getColorWithFallback()` with appropriate highlight groups
2. If the value should use pi's default, use empty string `""`
   with explanatory comment
3. Update the TODO.md if there's a related item

### Updating TODO Items

- Mark completed items with `[x]` in your local TODO.md if the file exists

### Updating documentation

- For changes that may affect documentation, update the doc too

## Git Ignore Policy

- Entries in `.gitignore` are intentionally excluded from version control
  do not commit them
- Never use `git add -A`, each changes should have it own commit base on content of the change itself
