local config = require("spacewalk.config")

local M = {}

--- Cached list of scanned project roots. `nil` means "never scanned yet".
---@type string[]|nil
local results = nil

--- Whether we have already warned about a missing scan executable, so we only nag once.
local warned = false

--- Resolve the scan command, appending the configured roots as trailing arguments.
---@param opts spacewalk.Config
---@return string[]
local function build_argv(opts)
	local cmd = opts.scan_cmd or config.default_scan_cmd(opts)
	local argv = vim.deepcopy(cmd)
	vim.list_extend(argv, opts.roots)
	return argv
end

--- Turn raw stdout (one `.git` path per line) into a deduped list of project roots.
---@param stdout string|nil
---@return string[]
local function parse(stdout)
	local seen, roots = {}, {}
	for _, line in ipairs(vim.split(stdout or "", "\n", { trimempty = true })) do
		-- Normalize first: fd appends a trailing slash to directories and may emit
		-- backslashes on Windows; normalize strips both so dirname yields the root.
		local root = vim.fs.dirname(vim.fs.normalize(line))
		if root ~= "" and not seen[root] then
			seen[root] = true
			table.insert(roots, root)
		end
	end
	return roots
end

--- True if the scan executable is available, warning (once) if not.
---@param opts spacewalk.Config
---@return boolean
local function executable(opts)
	local argv = opts.scan_cmd or config.default_scan_cmd(opts)
	if vim.fn.executable(argv[1]) == 1 then
		return true
	end
	if not warned then
		warned = true
		vim.notify(
			("spacewalk: scan command %q not found; only manual directories will be listed"):format(argv[1]),
			vim.log.levels.WARN
		)
	end
	return false
end

--- Run the scan asynchronously and cache the result.
---@param cb fun(roots: string[])|nil Called with the roots once the scan completes.
function M.scan(cb)
	local opts = config.options
	if #opts.roots == 0 or not executable(opts) then
		results = {}
		if cb then
			cb(results)
		end
		return
	end

	vim.system(build_argv(opts), { text = true }, function(out)
		local roots = parse(out.stdout)
		vim.schedule(function()
			results = roots
			if cb then
				cb(roots)
			end
		end)
	end)
end

--- Return the cached roots, scanning synchronously once if the cache is cold.
---@return string[]
function M.get()
	if results ~= nil then
		return results
	end

	local opts = config.options
	if #opts.roots == 0 or not executable(opts) then
		results = {}
		return results
	end

	-- Cold cache and someone needs the list now: block just this once.
	local out = vim.system(build_argv(opts), { text = true }):wait()
	results = parse(out.stdout)
	return results
end

--- Clear the cache and kick off a fresh asynchronous scan.
---@param cb fun(roots: string[])|nil
function M.refresh(cb)
	results = nil
	M.scan(cb)
end

return M
