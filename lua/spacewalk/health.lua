local config = require("spacewalk.config")

local M = {}

--- `:checkhealth spacewalk`
function M.check()
	local h = vim.health
	h.start("spacewalk")

	local opts = config.options

	-- 1. Scan executable.
	local argv = opts.scan_cmd or config.default_scan_cmd(opts)
	if vim.fn.executable(argv[1]) == 1 then
		h.ok(("scan command %q is executable"):format(argv[1]))
	else
		h.warn(
			("scan command %q not found"):format(argv[1]),
			{ "Install fd (https://github.com/sharkdp/fd) or set `scan_cmd` to another tool." }
		)
	end

	-- 2. Configured roots.
	if vim.tbl_isempty(opts.roots) then
		h.warn("no `roots` configured", { "Set `roots` in setup() to scan dev directories for git projects." })
	else
		for _, root in ipairs(opts.roots) do
			if vim.fn.isdirectory(root) == 1 then
				h.ok(("root exists: %s"):format(root))
			else
				h.warn(("root does not exist: %s"):format(root))
			end
		end
	end

	-- 3. Manual dirs (informational).
	for _, dir in ipairs(opts.manual) do
		if vim.fn.isdirectory(dir) == 1 then
			h.ok(("manual dir exists: %s"):format(dir))
		else
			h.warn(("manual dir does not exist: %s"):format(dir))
		end
	end

	-- 4. At least one supported picker.
	local found = {}
	if pcall(require, "telescope") then
		table.insert(found, "telescope")
	end
	if pcall(require, "snacks") then
		table.insert(found, "snacks")
	end
	if vim.tbl_isempty(found) then
		h.error("no supported picker found", { "Install telescope.nvim or snacks.nvim." })
	else
		h.ok(("picker available: %s"):format(table.concat(found, ", ")))
	end
end

return M
