-- Auto-load pi-theme-sync if user has configured it via global
-- This allows zero-config setup by setting vim.g.pi_theme_sync_config

if vim.g.pi_theme_sync_auto_setup ~= false then
	local ok, pi_theme_sync = pcall(require, "pi-theme-sync")
	if ok and vim.g.pi_theme_sync_config then
		pi_theme_sync.setup(vim.g.pi_theme_sync_config)
	end
end
