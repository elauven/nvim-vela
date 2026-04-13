-- lua/vela/lsp.lua
-- Handles vela-lsp server registration, lifecycle, and LSP keymaps.
-- Works with both bare vim.lsp and nvim-lspconfig (if installed).

local M = {}

-- ─────────────────────────────────────────────
--  Binary resolution
-- ─────────────────────────────────────────────

---Find the vela-lsp binary.
---Priority: config.lsp.bin > ./vela-lsp (project) > PATH
---@param config VelaConfig
---@return string|nil
local function resolve_bin(config)
  local bin = config.lsp.bin
  if bin and bin ~= "" then
    if vim.fn.executable(bin) == 1 then
      return bin
    end
    vim.notify(
      string.format("vela-lsp: configured bin not found: %s", bin),
      vim.log.levels.WARN
    )
  end

  -- Project-local binary (monorepo / after `go build`)
  local cwd_bin = vim.fn.getcwd() .. "/vela-lsp"
  if vim.fn.executable(cwd_bin) == 1 then
    return cwd_bin
  end

  -- PATH
  if vim.fn.executable("vela-lsp") == 1 then
    return "vela-lsp"
  end

  return nil
end

-- ─────────────────────────────────────────────
--  Root directory detection
-- ─────────────────────────────────────────────

---Walk up the directory tree to find a root marker.
---@param buf number
---@param markers string[]
---@return string
local function find_root(buf, markers)
  local fname = vim.api.nvim_buf_get_name(buf)
  if fname == "" then
    return vim.fn.getcwd()
  end
  local dir = vim.fn.fnamemodify(fname, ":p:h")
  local result = vim.fs.find(markers, { path = dir, upward = true })[1]
  if result then
    return vim.fn.fnamemodify(result, ":h")
  end
  return dir
end

-- ─────────────────────────────────────────────
--  Default on_attach keymaps
-- ─────────────────────────────────────────────

---Attach default keymaps and LSP behaviours to a buffer.
---@param client vim.lsp.Client
---@param bufnr number
---@param config VelaConfig
local function default_on_attach(client, bufnr, config)
  local km = config.keymaps
  if not km.enable then return end

  local map = function(mode, lhs, rhs, desc)
    if lhs then
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
    end
  end

  -- Navigation
  map("n", km.goto_definition,  vim.lsp.buf.definition,      "Go to definition")
  map("n", km.hover,            vim.lsp.buf.hover,           "Hover documentation")
  map("n", km.references,       vim.lsp.buf.references,      "Find references")
  map("n", km.rename,           vim.lsp.buf.rename,          "Rename symbol")
  map("n", km.code_action,      vim.lsp.buf.code_action,     "Code actions")
  map("v", km.code_action,      vim.lsp.buf.code_action,     "Code actions (range)")

  -- Formatting
  map("n", km.format, function()
    vim.lsp.buf.format({
      async = false,
      timeout_ms = 2000,
      filter = function(c) return c.name == "vela-lsp" end,
    })
  end, "Format file")

  -- Diagnostics
  map("n", km.diagnostics_next,  vim.diagnostic.goto_next,   "Next diagnostic")
  map("n", km.diagnostics_prev,  vim.diagnostic.goto_prev,   "Prev diagnostic")
  map("n", km.diagnostics_float, vim.diagnostic.open_float,  "Diagnostic details")

  -- Show signature help on insert-mode parenthesis
  if client.server_capabilities.signatureHelpProvider then
    map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
  end

  -- Highlight symbol under cursor on CursorHold
  if client.server_capabilities.documentHighlightProvider then
    local group = vim.api.nvim_create_augroup("VelaDocHighlight", { clear = false })
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group    = group,
      buffer   = bufnr,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd("CursorMoved", {
      group    = group,
      buffer   = bufnr,
      callback = vim.lsp.buf.clear_references,
    })
  end
end

-- ─────────────────────────────────────────────
--  Server start (bare vim.lsp)
-- ─────────────────────────────────────────────

-- Track active clients per root
local clients = {} -- root → client_id

---Start vela-lsp for the given buffer (bare vim.lsp path).
---@param bufnr number
---@param config VelaConfig
function M.start(bufnr, config)
  local bin = resolve_bin(config)
  if not bin then
    vim.notify(
      "vela-lsp binary not found.\n" ..
      "Build it: cd vela/lsp && go build -o vela-lsp .\n" ..
      "Then add to PATH or set vim.g.vela_lsp_bin.",
      vim.log.levels.ERROR
    )
    return
  end

  local root = find_root(bufnr, config.lsp.root_markers)
  local cmd  = vim.list_extend({ bin }, config.lsp.args or {})

  -- Reuse existing client for this root
  if clients[root] then
    local existing = vim.lsp.get_client_by_id(clients[root])
    if existing then
      vim.lsp.buf_attach_client(bufnr, clients[root])
      return
    end
    clients[root] = nil
  end

  -- Build capabilities
  local caps = vim.lsp.protocol.make_client_capabilities()
  -- Enable snippet support for completions
  caps.textDocument.completion.completionItem.snippetSupport = true
  caps.textDocument.completion.completionItem.resolveSupport = {
    properties = { "documentation", "detail", "additionalTextEdits" },
  }
  if config.lsp.capabilities then
    caps = vim.tbl_deep_extend("force", caps, config.lsp.capabilities)
  end
  -- Merge cmp-nvim-lsp capabilities if available
  local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if ok then
    caps = vim.tbl_deep_extend("force", caps, cmp_lsp.default_capabilities())
  end

  local client_id = vim.lsp.start({
    name            = "vela-lsp",
    cmd             = cmd,
    root_dir        = root,
    capabilities    = caps,
    settings        = config.lsp.settings,
    filetypes       = { "vela" },
    init_options    = {
      diagnosticsEnabled = true,
      formatEnabled      = true,
      formatTabSize      = config.format.tab_size,
    },
    on_attach = function(client, buf)
      -- User-supplied on_attach
      if type(config.lsp.on_attach) == "function" then
        config.lsp.on_attach(client, buf)
      end
      -- Default keymaps (unless user set on_attach = false)
      if config.lsp.on_attach ~= false then
        default_on_attach(client, buf, config)
      end
    end,
    on_exit = function()
      clients[root] = nil
    end,
  })

  if client_id then
    clients[root] = client_id
  end
end

-- ─────────────────────────────────────────────
--  nvim-lspconfig registration (optional)
-- ─────────────────────────────────────────────

---Register vela-lsp with nvim-lspconfig.
---Call this if you prefer to manage servers via lspconfig.
---@param config VelaConfig
function M.register(config)
  local ok, lspconfig = pcall(require, "lspconfig")
  if not ok then
    -- No lspconfig — will use bare vim.lsp.start() instead
    return
  end

  local configs = require("lspconfig.configs")

  -- Only register once
  if configs.vela then return end

  configs.vela = {
    default_config = {
      cmd          = { resolve_bin(config) or "vela-lsp" },
      filetypes    = { "vela" },
      root_dir     = lspconfig.util.root_pattern(
        unpack(config.lsp.root_markers)
      ),
      single_file_support = true,
      settings     = config.lsp.settings,
      init_options = {
        diagnosticsEnabled = true,
        formatEnabled      = true,
        formatTabSize      = config.format.tab_size,
      },
    },
    docs = {
      description  = "Vela single-file component language server",
      default_config = {
        root_dir = "Project root (nearest package.json, .git, or go.mod)",
      },
    },
  }

  -- Auto-start via lspconfig
  lspconfig.vela.setup({
    capabilities = (function()
      local caps = vim.lsp.protocol.make_client_capabilities()
      caps.textDocument.completion.completionItem.snippetSupport = true
      local cok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if cok then
        return vim.tbl_deep_extend("force", caps, cmp_lsp.default_capabilities())
      end
      return caps
    end)(),
    on_attach = function(client, bufnr)
      if type(config.lsp.on_attach) == "function" then
        config.lsp.on_attach(client, bufnr)
      end
      if config.lsp.on_attach ~= false then
        default_on_attach(client, bufnr, config)
      end
    end,
  })
end

-- ─────────────────────────────────────────────
--  Restart / info
-- ─────────────────────────────────────────────

---Restart all active vela-lsp clients.
function M.restart()
  for root, id in pairs(clients) do
    local client = vim.lsp.get_client_by_id(id)
    if client then
      client.stop(true)
    end
    clients[root] = nil
  end

  -- Re-attach all open .vela buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].filetype == "vela" then
      local cfg = require("vela").config
      M.start(bufnr, cfg)
    end
  end
end

---Show LSP status in a floating window.
function M.show_info()
  local lines = { "# Vela LSP Status", "" }

  for root, id in pairs(clients) do
    local client = vim.lsp.get_client_by_id(id)
    if client then
      table.insert(lines, string.format("● Active (id=%d)", id))
      table.insert(lines, string.format("  Root:    %s", root))
      table.insert(lines, string.format("  Command: %s", table.concat(client.config.cmd, " ")))
    else
      table.insert(lines, string.format("✗ Dead client (id=%d)", id))
    end
  end

  if vim.tbl_isempty(clients) then
    table.insert(lines, "No active clients.")
  end

  -- Also show active clients for current buffer
  table.insert(lines, "")
  table.insert(lines, "## Attached to current buffer")
  local bufnr = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == "vela-lsp" then
      table.insert(lines, string.format("  ✓ %s (id=%d)", client.name, client.id))
    end
  end

  -- Show in a popup
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  local width  = math.min(70, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row      = math.floor((vim.o.lines - height) / 2),
    col      = math.floor((vim.o.columns - width) / 2),
    width    = width,
    height   = height,
    style    = "minimal",
    border   = "rounded",
    title    = " Vela LSP ",
    title_pos = "center",
  })

  -- Close with q or Escape
  vim.keymap.set("n", "q",      "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>",  "<cmd>close<cr>", { buffer = buf, silent = true })
end

return M
