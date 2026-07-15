-- Guard against double-sourcing (e.g. when packaged and also dev-loaded).
if vim.g.loaded_spacewalk then
	return
end
vim.g.loaded_spacewalk = true

vim.api.nvim_create_user_command("Spacewalk", function(cmd)
	local name = cmd.args ~= "" and cmd.args or nil
	require("spacewalk").pick(name)
end, {
	nargs = "?",
	complete = function()
		return { "telescope", "snacks" }
	end,
	desc = "Pick a project directory and :tcd into it",
})

vim.api.nvim_create_user_command("SpacewalkRefresh", function()
	require("spacewalk").refresh()
end, {
	desc = "Re-scan spacewalk roots for project directories",
})
