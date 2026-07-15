local M = {}

--- Open the spacewalk directory picker using Telescope.
---@param opts table|nil Telescope picker opts, forwarded through.
function M.open(opts)
	opts = opts or {}

	local spacewalk = require("spacewalk")
	local config = require("spacewalk.config")
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local dirs = spacewalk.dirs()
	if vim.tbl_isempty(dirs) then
		vim.notify("spacewalk: no directories to show (check `roots`/`manual`)", vim.log.levels.WARN)
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Spacewalk",
			finder = finders.new_table({
				results = dirs,
				entry_maker = function(entry)
					return {
						value = entry,
						display = string.format("%-24s %s", entry.name, entry.dir),
						ordinal = entry.name .. " " .. entry.dir,
						path = entry.dir,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				-- Plain confirm: switch and close.
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection then
						spacewalk.switch(selection.value.dir)
					end
				end)

				-- User-defined post-:tcd actions: switch, then run the callback.
				for key, action in pairs(config.options.actions) do
					map({ "i", "n" }, key, function()
						local selection = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if selection then
							local dir = selection.value.dir
							spacewalk.switch(dir)
							action.fn(dir)
						end
					end, { desc = action.desc })
				end

				return true
			end,
		})
		:find()
end

return M
