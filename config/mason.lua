-- config/mason.lua
-- Integrates vela-lsp with mason.nvim and mason-lspconfig.nvim.
-- Mason normally installs pre-built binaries from a registry.
-- Since vela-lsp is a custom server, we register it manually
-- and use mason only for the UI / PATH management.
--
-- Recommended approach: build vela-lsp once and add to PATH.
-- This file shows two alternatives:
--   A) Manual PATH install (recommended)
--   B) mason-registry package registration (future/advanced)

-- ─────────────────────────────────────────────
--  A) Manual install (simpler, always works)
-- ─────────────────────────────────────────────
--
-- 1. Build:
--      cd vela/lsp && go build -o vela-lsp .
--
-- 2. Install to mason's bin directory so mason tracks it:
--      mv vela-lsp ~/.local/share/nvim/mason/bin/vela-lsp
--
-- 3. That's it — vela-lsp is now on the mason-managed PATH.

-- ─────────────────────────────────────────────
--  B) mason-tool-installer (auto-install on startup)
-- ─────────────────────────────────────────────

-- If using WhoIsSethDaniel/mason-tool-installer.nvim:
--
--   require("mason-tool-installer").setup({
--     ensure_installed = {
--       -- standard tools
--       "lua-language-server",
--       "typescript-language-server",
--       -- vela-lsp: not in mason registry, install via shell hook instead
--     },
--   })

-- ─────────────────────────────────────────────
--  C) Auto-build hook (lazy.nvim build option)
-- ─────────────────────────────────────────────
--
-- In your lazy.nvim spec for nvim-vela, add:
--
--   {
--     dir = "~/.config/nvim/nvim-vela",
--     build = function()
--       -- Build vela-lsp from the companion compiler repo
--       local lsp_dir = vim.fn.expand("~/.local/share/nvim/vela-lsp-src")
--       if vim.fn.isdirectory(lsp_dir) == 0 then
--         vim.fn.system("git clone https://github.com/elauven/vela " .. lsp_dir)
--       end
--       vim.fn.system("cd " .. lsp_dir .. "/lsp && go build -o ~/.local/share/nvim/mason/bin/vela-lsp .")
--       vim.notify("vela-lsp built and installed to mason bin", vim.log.levels.INFO)
--     end,
--   }

-- ─────────────────────────────────────────────
--  D) Full mason + lspconfig setup example
-- ─────────────────────────────────────────────

local function setup_with_mason()
  local ok_mason, mason = pcall(require, "mason")
  if not ok_mason then return end

  mason.setup({
    ui = {
      border = "rounded",
      icons  = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
    },
    -- Add mason's bin to PATH so vela-lsp is always found
    PATH = "prepend",
  })

  -- mason-lspconfig handles auto-setup for servers in the mason registry.
  -- vela-lsp is NOT in the registry, so we set it up separately below.
  local ok_mlsp, mason_lspconfig = pcall(require, "mason-lspconfig")
  if ok_mlsp then
    mason_lspconfig.setup({
      ensure_installed = {
        "lua_ls",
        "ts_ls",
        -- "vela" would go here once added to the registry
      },
      automatic_installation = true,
    })
  end

  -- Register vela separately via nvim-lspconfig
  local ok_lsp, lspconfig = pcall(require, "lspconfig")
  if not ok_lsp then return end

  local configs = require("lspconfig.configs")
  if not configs.vela then
    configs.vela = {
      default_config = {
        cmd          = { "vela-lsp" },
        filetypes    = { "vela" },
        root_dir     = lspconfig.util.root_pattern("package.json", ".git", "go.mod"),
        single_file_support = true,
        init_options = { diagnosticsEnabled = true, formatEnabled = true },
      },
    }
  end

  -- Build capabilities with cmp-nvim-lsp if available
  local caps = vim.lsp.protocol.make_client_capabilities()
  caps.textDocument.completion.completionItem.snippetSupport = true
  local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if ok_cmp then
    caps = vim.tbl_deep_extend("force", caps, cmp_lsp.default_capabilities())
  end

  lspconfig.vela.setup({
    capabilities = caps,
    on_attach    = function(client, bufnr)
      -- Standard keymaps
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
      end
      map("gd",         vim.lsp.buf.definition,  "Go to definition")
      map("gD",         vim.lsp.buf.declaration, "Go to declaration")
      map("K",          vim.lsp.buf.hover,        "Hover docs")
      map("gi",         vim.lsp.buf.implementation, "Go to implementation")
      map("gr",         vim.lsp.buf.references,   "Find references")
      map("<leader>rn", vim.lsp.buf.rename,        "Rename symbol")
      map("<leader>ca", vim.lsp.buf.code_action,   "Code action")
      map("<leader>f",  function()
        vim.lsp.buf.format({ async = false, timeout_ms = 3000 })
      end, "Format")
      map("]d",         vim.diagnostic.goto_next,  "Next diagnostic")
      map("[d",         vim.diagnostic.goto_prev,  "Prev diagnostic")
      map("<leader>e",  vim.diagnostic.open_float, "Diagnostic float")
      map("<leader>q",  vim.diagnostic.setloclist, "Diagnostic list")
    end,
  })
end

setup_with_mason()
