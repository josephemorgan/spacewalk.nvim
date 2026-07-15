# spacewalk.nvim

Jump between your projects by changing the **tab** working directory (`:tcd`).

`spacewalk` builds a list of project directories from:

1. a **recursive scan** of your configured dev directories (a folder is a project if it
   contains a `.git`), and
2. a **static list** of manually-added directories.

Pick one from [telescope](https://github.com/nvim-telescope/telescope.nvim) **or**
[snacks.picker](https://github.com/folke/snacks.nvim), and spacewalk runs `:tcd` into it.
Optionally, bind extra keys inside the picker to run whatever you want next — open a file
picker, drop into a terminal, launch a file browser — scoped to the chosen directory.

## How it works

There is one picker-agnostic **core** (scan → list → `:tcd` → optional action) and a thin
adapter per picker. The core ships no picker-specific code, so telescope and snacks behave
identically and a third picker would be a small adapter away.

## Requirements

- Neovim >= 0.10 (uses `vim.system`)
- [`fd`](https://github.com/sharkdp/fd) on your `PATH` (default scanner; configurable)
- telescope.nvim **or** snacks.nvim

Run `:checkhealth spacewalk` to verify your setup.

## Install (lazy.nvim)

```lua
{
  "yourname/spacewalk.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim", -- or "folke/snacks.nvim"
  },
  opts = {
    roots = { "~/dev", "~/work" }, -- scanned recursively for .git
    manual = { "~/.config/nvim" }, -- always listed, no scan needed
  },
  keys = {
    { "<leader>fp", function() require("spacewalk").pick() end, desc = "Spacewalk: pick project" },
  },
}
```

`opts` is passed to `require("spacewalk").setup()`. If you are not using lazy's `opts`, call
`require("spacewalk").setup({ ... })` yourself.

## Configuration

```lua
require("spacewalk").setup({
  -- Dev directories scanned recursively for `.git`.
  roots = { "~/dev" },

  -- Directories always shown (no scan required).
  manual = {},

  -- Preferred picker; nil auto-detects whichever is installed.
  picker = nil, -- "telescope" | "snacks" | nil

  -- Scan depth for the default fd command.
  max_depth = 4,

  -- Override the scan command entirely. Roots are appended as trailing args.
  -- Default: { "fd", "--hidden", "--type", "d", "--max-depth", <depth>, "^\\.git$" }
  scan_cmd = nil,

  -- Optional hook run after every plain confirm.
  on_switch = nil, -- function(dir) end

  -- Keymaps run *after* :tcd, inside the picker. Each fn receives the chosen dir.
  actions = {},
})
```

## Usage

- `:Spacewalk` — open with the auto-detected (or configured) picker
- `:Spacewalk snacks` / `:Spacewalk telescope` — force a picker
- `:Telescope spacewalk` — via telescope's extension registry
- `:SpacewalkRefresh` — re-scan the roots
- `require("spacewalk").pick("snacks")` — from a keymap

To use the telescope extension explicitly:

```lua
require("telescope").load_extension("spacewalk")
```

## Post-`:tcd` actions

`actions` maps a keymap (as pressed inside the picker) to a callback. spacewalk always runs
`:tcd` into the highlighted directory first, then calls your function with that directory:

```lua
require("spacewalk").setup({
  roots = { "~/dev" },
  actions = {
    -- Telescope users: open find_files in the chosen project
    ["<C-f>"] = {
      desc = "Find files",
      fn = function(dir)
        require("telescope.builtin").find_files({ cwd = dir })
      end,
    },
    -- snacks users: open the file picker in the chosen project
    ["<C-g>"] = {
      desc = "Grep",
      fn = function(dir)
        Snacks.picker.grep({ dirs = { dir } })
      end,
    },
    -- Open a terminal in the chosen project
    ["<C-t>"] = {
      desc = "Terminal here",
      fn = function(dir)
        vim.cmd.tabnew()
        vim.cmd.terminal()
      end,
    },
    -- Open a file browser (netrw / oil / etc.) in the chosen project
    ["<C-e>"] = {
      desc = "File browser",
      fn = function(dir)
        vim.cmd.edit(dir)
      end,
    },
  },
})
```

The same `actions` table works for both pickers — spacewalk registers the keys natively in
whichever picker you open.

## Notes

- Nested repositories (e.g. git submodules) within `max_depth` may appear as separate
  entries. Lower `max_depth` or point `roots` more precisely to avoid this.
- Without `fd` (or a configured `scan_cmd` executable), scanning is skipped and only your
  `manual` directories are listed.
