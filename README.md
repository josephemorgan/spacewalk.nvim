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
  "josephemorgan/spacewalk.nvim",
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

  -- Extra snacks.picker options, deep-merged into the picker call.
  -- By default the preview pane lists the highlighted project's files.
  -- To turn the preview off entirely:
  --   snacks = { preview = "none" }
  -- or use a compact, preview-less layout:
  --   snacks = { layout = { preset = "select" } }
  snacks = {},
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

`actions` maps a keymap (the key as pressed inside the picker) to a callback. When you press
the key on a highlighted entry, spacewalk:

1. closes the picker,
2. runs `:tcd` into that entry's directory, then
3. calls your `fn(dir)` with the chosen directory.

So every action lands you in the project first, and your callback decides what happens next.

**Modes:** you do not need to register anything for insert mode. spacewalk binds each action
in **both normal and insert mode**, so the keys work while you are still typing in the
picker's prompt (insert) or after you have moved into the list (normal).

**Overriding built-ins:** your key takes precedence over the picker's built-in mapping for
the same key. Pickers ship their own defaults — snacks, for example, maps `<c-p>` to
`list_up`, `<c-t>` to `tab`, and `<c-b>` to `preview_scroll_up`. Binding one of those in
`actions` replaces it while the picker is open. Write chords in lowercase (`<c-p>`, not
`<C-p>`); spacewalk lowercases them for you before handing them to snacks so the override
lands cleanly, but using lowercase yourself keeps your config unambiguous. Pick a
non-conflicting key if you'd rather keep the built-in.

The same `actions` table works for both pickers — spacewalk registers the keys natively in
whichever picker you open.

### Example: pick / browse / terminal

`<c-p>` to fuzzy-find files, `<c-b>` to open a file browser, `<c-t>` to open a terminal —
all scoped to the project you land in. (These three replace snacks' built-in `list_up` /
`preview_scroll_up` / `tab` while the picker is open; see "Overriding built-ins" above.)

```lua
require("spacewalk").setup({
  roots = { "~/dev" },
  actions = {
    -- <c-p>: fuzzy-find files in the chosen project
    ["<c-p>"] = {
      desc = "Pick Files",
      fn = function(dir)
        Snacks.picker.files({ cwd = dir })
        -- telescope: require("telescope.builtin").find_files({ cwd = dir })
      end,
    },
    -- <c-b>: browse files in the chosen project
    ["<c-b>"] = {
      desc = "Browse Files",
      fn = function(dir)
        Snacks.explorer({ cwd = dir })
        -- oil:                    require("oil").open(dir)
        -- netrw:                  vim.cmd.edit(dir)
        -- telescope-file-browser:
        --   require("telescope").extensions.file_browser.file_browser({ cwd = dir })
      end,
    },
    -- <c-t>: open a terminal in the chosen project
    ["<c-t>"] = {
      desc = "Open Terminal",
      fn = function(dir)
        Snacks.terminal(nil, { cwd = dir })
        -- builtin: vim.cmd.terminal()  -- inherits the tcd'd cwd already
      end,
    },
  },
})
```

> **Note on `cwd = dir`.** spacewalk has already run `:tcd dir`, so a bare
> `Snacks.terminal()` or `find_files()` would inherit that directory. But `:tcd` is
> *tab*-scoped, and some tools read the global cwd or a stored root instead — passing
> `cwd = dir` explicitly removes the ambiguity. Swap the bodies for whatever file
> picker / browser / terminal plugins you actually use.

## Notes

- Nested repositories (e.g. git submodules) within `max_depth` may appear as separate
  entries. Lower `max_depth` or point `roots` more precisely to avoid this.
- Without `fd` (or a configured `scan_cmd` executable), scanning is skipped and only your
  `manual` directories are listed.
