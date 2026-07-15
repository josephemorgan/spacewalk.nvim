---@class spacewalk.Action
---@field desc string       Description shown in picker keymap hints.
---@field fn fun(dir: string) Callback run after :tcd, receiving the chosen directory.

---@class spacewalk.Config
---@field roots string[]                       Dev directories scanned recursively for git roots.
---@field manual string[]                       Extra directories always shown (no scan needed).
---@field scan_cmd string[]|nil                 Override the scan command. `nil` = built default (fd).
---@field max_depth integer                     Max scan depth passed to the default fd command.
---@field picker "telescope"|"snacks"|nil       Preferred picker. `nil` = auto-detect what is loaded.
---@field actions table<string, spacewalk.Action> Keymap -> post-:tcd callback.
---@field on_switch fun(dir: string)|nil        Optional hook run after every plain confirm.
---@field snacks table                          Extra snacks.picker opts, deep-merged in (e.g. `preview`, `layout`).

local M = {}

---@type spacewalk.Config
local defaults = {
	roots = {},
	manual = {},
	scan_cmd = nil,
	max_depth = 4,
	picker = nil,
	actions = {},
	on_switch = nil,
	snacks = {},
}

---@type spacewalk.Config
M.options = vim.deepcopy(defaults)

--- Build the default fd command used to locate `.git` directories.
--- Kept as a function so `max_depth` is read at call time.
---@param opts spacewalk.Config
---@return string[]
function M.default_scan_cmd(opts)
	return {
		"fd",
		"--hidden", -- .git is a dotfile, so it is hidden by default
		"--type",
		"d",
		"--max-depth",
		tostring(opts.max_depth),
		"^\\.git$", -- match the .git directory exactly
	}
end

--- Merge user options over the defaults.
---@param opts spacewalk.Config|nil
---@return spacewalk.Config
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	-- Expand `~` and environment variables in configured paths up front so every
	-- consumer (scan, picker, health) sees absolute paths.
	M.options.roots = vim.tbl_map(vim.fs.normalize, M.options.roots)
	M.options.manual = vim.tbl_map(vim.fs.normalize, M.options.manual)
	return M.options
end

return M
