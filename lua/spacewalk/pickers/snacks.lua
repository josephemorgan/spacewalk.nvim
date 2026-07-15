local M = {}

--- Open the spacewalk directory picker using snacks.picker.
---@param opts table|nil Extra snacks.picker options, merged in.
function M.open(opts)
	local spacewalk = require("spacewalk")
	local config = require("spacewalk.config")

	if not Snacks or not Snacks.picker then
		vim.notify("spacewalk: snacks.picker is not available", vim.log.levels.ERROR)
		return
	end

	local dirs = spacewalk.dirs()
	if vim.tbl_isempty(dirs) then
		vim.notify("spacewalk: no directories to show (check `roots`/`manual`)", vim.log.levels.WARN)
		return
	end

	-- Map our {dir, name} entries onto snacks items. `text` drives both display
	-- (via format = "text") and matching. `file` points the built-in previewer at
	-- the directory, so the preview pane lists that project's contents.
	local items = {}
	for _, entry in ipairs(dirs) do
		table.insert(items, {
			text = string.format("%-24s %s", entry.name, entry.dir),
			dir = entry.dir,
			file = entry.dir,
		})
	end

	-- Translate config.actions into snacks actions + input keymaps.
	--
	-- snacks stores its built-in picker keymaps in lowercase chord notation
	-- (e.g. "<c-p>" = list_up, "<c-t>" = tab, "<c-b>" = preview_scroll_up). Lua
	-- table keys are case-sensitive, so an uppercase "<C-p>" is a *different* key
	-- and does NOT override the default during the config merge -- both survive,
	-- collide on the same physical key, and the built-in wins (snacks warns
	-- "Duplicate key mapping ... check case"). Lowercasing chord notation makes our
	-- key byte-identical to the default so it cleanly replaces it.
	local function canonical(key)
		return key:match("^<.->$") and key:lower() or key
	end

	local snacks_actions, keys = {}, {}
	for key, action in pairs(config.options.actions) do
		local lhs = canonical(key)
		local name = "spacewalk_" .. lhs
		snacks_actions[name] = function(picker, item)
			picker:close()
			if item then
				spacewalk.switch(item.dir)
				action.fn(item.dir)
			end
		end
		keys[lhs] = { name, mode = { "n", "i" }, desc = action.desc }
	end

	Snacks.picker.pick(vim.tbl_deep_extend("force", {
		title = "Spacewalk",
		items = items,
		format = "text",
		confirm = function(picker, item)
			picker:close()
			if item then
				spacewalk.switch(item.dir)
			end
		end,
		actions = snacks_actions,
		win = { input = { keys = keys } },
	}, config.options.snacks or {}, opts or {}))
end

return M
