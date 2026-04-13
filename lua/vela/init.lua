-- lua/vela/init.lua
-- Main Vela Neovim plugin module.
-- Registers the LSP server and exposes setup().

local M = {}

-- ─────────────────────────────────────────────
--  Default configuration
-- ─────────────────────────────────────────────

---@class VelaConfig
---@field lsp VelaLspConfig
---@field keymaps VelaKeymapConfig
---@field format VelaFormatConfig
local defaults = {
  lsp = {
    -- Path to the vela-lsp binary.
    -- "" means auto-detect: check local ./vela-lsp, then PATH.
    bin = "",

    -- Extra arguments passed to vela-lsp
    args = {},

    -- LSP on_attach callback (runs for every .vela buffer)
    -- Receives (client, bufnr). Set to false to skip default keymaps.
    on_attach = nil,

    -- Passed to vim.lsp.start() / nvim-lspconfig
    capabilities = nil,

    -- Root markers: walk up from the file until one is found
    root_markers = { "package.json", ".git", "go.mod" },

    -- Per-buffer settings sent to the server
    settings = {},
  },
  keymaps = {
    -- Set to false to disable all default keymaps
    enable = true,
    -- Individual keymaps (set to false to disable one)
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
    -- Format on save
    on_save = false,
    tab_size = 2,
    insert_spaces = true,
  },
}

---@type VelaConfig
M.config = vim.deepcopy(defaults)

-- ─────────────────────────────────────────────
--  Setup
-- ─────────────────────────────────────────────

---Configure and start the Vela LSP.
---Call once in your init.lua / plugin spec.
---@param opts? VelaConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Register the LSP server definition
  require("vela.lsp").register(M.config)

  -- Auto-start LSP when a .vela file is opened
  vim.api.nvim_create_autocmd("FileType", {
    pattern  = "vela",
    group    = vim.api.nvim_create_augroup("VelaLsp", { clear = true }),
    callback = function(ev)
      require("vela.lsp").start(ev.buf, M.config)
    end,
    desc = "Start vela-lsp for .vela files",
  })

  -- Format on save if enabled
  if M.config.format.on_save then
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern  = "*.vela",
      group    = vim.api.nvim_create_augroup("VelaFormat", { clear = true }),
      callback = function()
        vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
      end,
      desc = "Format .vela on save",
    })
  end

  -- User commands
  vim.api.nvim_create_user_command("VelaRestartLsp", function()
    require("vela.lsp").restart()
    vim.notify("Vela LSP restarted", vim.log.levels.INFO)
  end, { desc = "Restart the Vela language server" })

  vim.api.nvim_create_user_command("VelaInfo", function()
    require("vela.lsp").show_info()
  end, { desc = "Show Vela LSP status" })
end

return M
