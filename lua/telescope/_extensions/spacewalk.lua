-- Registers `:Telescope spacewalk`. All logic lives in the picker-agnostic core;
-- this shim just forwards to the telescope adapter.
return require("telescope").register_extension({
	exports = {
		spacewalk = function(opts)
			require("spacewalk.pickers.telescope").open(opts)
		end,
	},
})
