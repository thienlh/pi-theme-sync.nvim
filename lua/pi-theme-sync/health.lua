local M = {}

function M.check()
	local pi_theme_sync = require("pi-theme-sync")
	pi_theme_sync.checkhealth()
end

return M
