local config = require("spacewalk.config")
local scan = require("spacewalk.scan")

local M = {}

---@class spacewalk.Dir
---@field dir string    Absolute, normalized directory path.
---@field name string   Display name (the tail of the path).
---@field source "scanned"|"manual"

--- Configure the plugin and warm the scan cache in the background.
---@param opts spacewalk.Config|nil
function M.setup(opts)
	config.setup(opts)
	-- Fire and forget: the cache is ready by the time a picker usually opens,
	-- and scan.get() falls back to a synchronous scan if it is not.
	scan.scan()
end

--- The full, deduped list of switchable directories (scanned roots + manual dirs).
--- Manual entries win when a path appears in both.
---@return spacewalk.Dir[]
function M.dirs()
	local seen, dirs = {}, {}

	local function add(dir, source)
		dir = vim.fs.normalize(dir)
		if dir ~= "" and not seen[dir] then
			seen[dir] = true
			table.insert(dirs, {
				dir = dir,
				name = vim.fn.fnamemodify(dir, ":t"),
				source = source,
			})
		end
	end

	-- Manual first so they take precedence in the dedupe.
	for _, dir in ipairs(config.options.manual) do
		add(dir, "manual")
	end
	for _, dir in ipairs(scan.get()) do
		add(dir, "scanned")
	end

	return dirs
end

--- Change the current tab's working directory and run the on_switch hook.
---@param dir string
function M.switch(dir)
	local ok, err = pcall(vim.cmd.tcd, vim.fn.fnameescape(dir))
	if not ok then
		vim.notify(("spacewalk: could not :tcd to %s (%s)"):format(dir, err), vim.log.levels.ERROR)
		return
	end
	vim.notify(("spacewalk: tcd -> %s"):format(dir), vim.log.levels.INFO)
	if config.options.on_switch then
		config.options.on_switch(dir)
	end
end

--- Resolve which picker adapter to use: explicit name, then config, then auto-detect.
---@param name string|nil
---@return string|nil
local function resolve_picker(name)
	name = name or config.options.picker
	if name then
		return name
	end
	-- Auto-detect: prefer whichever is actually installed.
	for _, candidate in ipairs({ "telescope", "snacks" }) do
		if pcall(require, candidate == "telescope" and "telescope" or "snacks") then
			return candidate
		end
	end
	return nil
end

--- Open a picker of switchable directories.
---@param name "telescope"|"snacks"|nil
function M.pick(name)
	local picker = resolve_picker(name)
	if not picker then
		vim.notify("spacewalk: no supported picker found (telescope or snacks.nvim)", vim.log.levels.ERROR)
		return
	end

	local ok, adapter = pcall(require, "spacewalk.pickers." .. picker)
	if not ok then
		vim.notify(("spacewalk: unknown picker %q"):format(picker), vim.log.levels.ERROR)
		return
	end
	adapter.open()
end

--- Re-scan the configured roots.
function M.refresh()
	scan.refresh(function()
		vim.notify("spacewalk: refreshed", vim.log.levels.INFO)
	end)
end

return M
