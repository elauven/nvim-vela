# nvim-vela

Neovim LSP client and syntax support for the [Vela framework](https://github.com/elauven/vela).

## Features

- Syntax highlighting for `.vela` SFCs (`<script>`, `<style>`, `<template>`)
- LSP completions, hover docs, go-to-definition, diagnostics, formatting
- `]s` / `[s` — jump between script / style / template sections
- `<leader>vj` — open the compiled `.js` file in a split
- Works with bare `vim.lsp`, `nvim-lspconfig`, and `mason.nvim`

---

## Requirements

| Requirement | Version |
|---|---|
| Neovim | ≥ 0.10 |
| Go | ≥ 1.21 (to build `vela-lsp`) |
| `vela-lsp` binary | On PATH or configured |

---

## Installation

### Step 1 — Build vela-lsp

```bash
cd vela/lsp          # companion LSP server directory
go build -o vela-lsp ./cmd/lsp
sudo mv vela-lsp /usr/local/bin/   # or ~/bin/ or anywhere on $PATH
```

Verify:
```bash
vela-lsp --version
# vela-lsp 1.0.0
```

### Step 2 — Install the plugin

**lazy.nvim (recommended)**

```lua
-- In ~/.config/nvim/lua/plugins/vela.lua
return {
  {
    "elauven/nvim-vela",   -- GitHub URL (or use dir = "/path/to/nvim-vela" for local)
    ft = "vela",
    opts = {
      format = { on_save = true },
    },
  },
}
```

**packer.nvim**

```lua
use {
  "elauven/nvim-vela",
  ft = "vela",
  config = function()
    require("vela").setup({ format = { on_save = true } })
  end,
}
```

**Manual (no plugin manager)**

```bash
# Clone into the Neovim runtime path
git clone https://github.com/elauven/nvim-vela \
  ~/.local/share/nvim/site/pack/plugins/start/nvim-vela
```

Then in `init.lua`:
```lua
require("vela").setup()
```

---

## Configuration

`setup()` accepts a table — all fields are optional:

```lua
require("vela").setup({

  lsp = {
    -- Path to vela-lsp binary ("" = auto-detect from PATH)
    bin = "",

    -- Extra CLI args
    args = {},

    -- Custom on_attach (runs AFTER default keymaps)
    -- Set to false to skip default keymaps entirely
    on_attach = function(client, bufnr)
      -- your extra keymaps / settings here
    end,

    -- Merged with built-in capabilities
    -- (cmp-nvim-lsp capabilities are auto-merged if installed)
    capabilities = nil,

    -- Walk up from file until one of these is found → root_dir
    root_markers = { "package.json", ".git", "go.mod" },

    -- Sent to the server as workspace settings
    settings = {},
  },

  keymaps = {
    enable = true,          -- set false to skip ALL default keymaps

    -- Set any key to false to disable that mapping
    goto_definition   = "gd",
    hover             = "K",
    code_action       = "<leader>ca",
    rename            = "<leader>rn",
    references        = "gr",
    format            = "<leader>f",
    diagnostics_next  = "]d",
    diagnostics_prev  = "[d",
    diagnostics_float = "<leader>e",
  },

  format = {
    on_save       = false,   -- format on :w
    tab_size      = 2,
    insert_spaces = true,
  },

})
```

---

## Keymaps

### Default LSP keymaps (in every .vela buffer)

| Key | Action |
|---|---|
| `gd` | Go to definition (component source or var declaration) |
| `K` | Hover documentation |
| `gr` | Find references |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>f` | Format document |
| `]d` / `[d` | Next / prev diagnostic |
| `<leader>e` | Show diagnostic float |
| `<C-k>` (insert) | Signature help |

### Vela-specific keymaps

| Key | Action |
|---|---|
| `]s` | Jump to next SFC section (`<script>` → `<style>` → `<template>`) |
| `[s` | Jump to previous SFC section |
| `<leader>vj` | Open compiled `.js` in vertical split |
| `<leader>vr` | Restart the language server |

---

## Commands

| Command | Description |
|---|---|
| `:VelaRestartLsp` | Stop and restart the language server |
| `:VelaInfo` | Show server status, root, and command in a popup |

---

## Using with nvim-lspconfig

If you prefer managing servers through nvim-lspconfig:

```lua
-- Registers vela-lsp as a custom lspconfig server
require("vela").setup({
  lsp = {
    -- Keymaps / on_attach handled below
    on_attach = false,
  },
})

-- Then configure via lspconfig directly
require("lspconfig").vela.setup({
  on_attach = function(client, bufnr)
    -- your keymaps
  end,
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
```

---

## Using with mason.nvim

`vela-lsp` is not in the mason registry, but you can place the binary in mason's bin directory and it will be on the managed PATH:

```bash
# After building:
mv vela-lsp ~/.local/share/nvim/mason/bin/vela-lsp
```

Or use a lazy.nvim `build` hook to compile automatically:

```lua
{
  "elauven/nvim-vela",
  ft = "vela",
  build = "cd ../vela/lsp && go build -o ~/.local/share/nvim/mason/bin/vela-lsp .",
  opts = {},
}
```

---

## File Layout

```
nvim-vela/
├── ftdetect/vela.lua          Auto-detect .vela filetype
├── ftplugin/vela.lua          Buffer-local settings (indent, folds, keymaps)
├── syntax/vela.vim            Syntax highlighting (fallback without Tree-sitter)
├── plugin/vela.lua            Auto-load guard
├── lua/vela/
│   ├── init.lua               setup() + autocmds + user commands
│   ├── lsp.lua                Server start, keymaps, nvim-lspconfig registration
│   └── nav.lua                Section jump, open compiled JS
└── config/
    ├── minimal.lua            Minimal setup (no extra plugins)
    ├── lazy.lua               lazy.nvim plugin spec
    └── mason.lua              mason.nvim integration
```

---

## Troubleshooting

**vela-lsp not found**

```
:VelaInfo
```
Check the "Command" line. If empty or errored:
```bash
which vela-lsp          # should print a path
vela-lsp --version      # should print version
```

**No completions**

Run `:LspInfo` and verify vela-lsp shows as attached. Check `:messages` for errors on attach.

**Completions work but no snippets**

Add `snippetSupport = true` to capabilities — done automatically when `cmp-nvim-lsp` is installed.

**Wrong root directory**

Add a `package.json` or `.git` at your project root, or set:
```lua
require("vela").setup({
  lsp = { root_markers = { "vela.config.js", "package.json", ".git" } }
})
```

**Restart after config change**

```vim
:VelaRestartLsp
```
