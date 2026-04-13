-- config/minimal.lua
-- Minimal Vela LSP setup — only requires Neovim 0.10+ (built-in vim.lsp).
-- No nvim-lspconfig, no mason, no extra plugins.
--
-- Usage: add to your init.lua, or source this file from it:
--   require("config.minimal")

-- ─────────────────────────────────────────────
--  1. Detect .vela files
-- ─────────────────────────────────────────────

vim.filetype.add({ extension = { vela = "vela" } })

-- ─────────────────────────────────────────────
--  2. Start vela-lsp when a .vela file opens
-- ─────────────────────────────────────────────

vim.api.nvim_create_autocmd("FileType", {
  pattern = "vela",
  callback = function(ev)
    local root = vim.fs.root(ev.buf, { "package.json", ".git", "go.mod" })
      or vim.fn.getcwd()

    local caps = vim.lsp.protocol.make_client_capabilities()
    caps.textDocument.completion.completionItem.snippetSupport = true

    vim.lsp.start({
      name        = "vela-lsp",
      cmd         = { "vela-lsp" },    -- must be on PATH
      root_dir    = root,
      capabilities = caps,
      on_attach   = function(_, bufnr)
        -- Standard LSP keymaps
        local map = function(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("gd",          vim.lsp.buf.definition,   "Go to definition")
        map("K",           vim.lsp.buf.hover,         "Hover docs")
        map("gr",          vim.lsp.buf.references,    "References")
        map("<leader>rn",  vim.lsp.buf.rename,        "Rename")
        map("<leader>ca",  vim.lsp.buf.code_action,   "Code action")
        map("<leader>f",   function()
          vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
        end, "Format")
        map("]d",          vim.diagnostic.goto_next,  "Next diagnostic")
        map("[d",          vim.diagnostic.goto_prev,  "Prev diagnostic")
        map("<leader>e",   vim.diagnostic.open_float, "Diagnostic float")
      end,
    })
  end,
})

-- ─────────────────────────────────────────────
--  3. Diagnostic display style
-- ─────────────────────────────────────────────

vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
    source = "if_many",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    source = "always",
    border = "rounded",
  },
})
