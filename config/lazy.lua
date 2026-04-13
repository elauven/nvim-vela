-- config/lazy.lua
-- Plugin spec for lazy.nvim.
--
-- Add this table to your plugins list, e.g.:
--
--   require("lazy").setup({
--     { import = "plugins" },   -- or inline:
--     require("config.lazy"),
--   })

return {

  -- ─────────────────────────────────────────
  --  Vela language support
  -- ─────────────────────────────────────────
  {
    -- Local plugin path — replace with a GitHub URL when published:
    --   "elauven/nvim-vela",
    dir = vim.fn.stdpath("config") .. "/nvim-vela",   -- local checkout

    -- Lazy-load only when a .vela file is opened
    ft = "vela",

    -- Dependencies (all optional — graceful fallback if missing)
    dependencies = {
      "neovim/nvim-lspconfig",    -- optional: lspconfig integration
      "hrsh7th/cmp-nvim-lsp",    -- optional: completion capabilities boost
      "hrsh7th/nvim-cmp",        -- optional: completion UI
    },

    opts = {
      lsp = {
        -- bin = "/usr/local/bin/vela-lsp",  -- override if not on PATH
        on_attach = function(client, bufnr)
          -- Your custom on_attach goes here.
          -- The plugin adds standard LSP keymaps automatically;
          -- add project-specific ones here.
        end,
      },
      format = {
        on_save = true,     -- format on :w
        tab_size = 2,
      },
      keymaps = {
        enable = true,
        -- Override individual keymaps:
        -- goto_definition = "gD",
        -- hover = "<leader>h",
      },
    },

    config = function(_, opts)
      require("vela").setup(opts)
    end,
  },

  -- ─────────────────────────────────────────
  --  nvim-cmp setup (if not already configured)
  -- ─────────────────────────────────────────
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = false }),
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer",  keyword_length = 3 },
          { name = "path" },
        }),
        formatting = {
          format = function(entry, item)
            -- Show source name in completion menu
            local source_labels = {
              nvim_lsp = "[LSP]",
              luasnip  = "[Snippet]",
              buffer   = "[Buffer]",
              path     = "[Path]",
            }
            item.menu = source_labels[entry.source.name] or ""
            return item
          end,
        },
        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end,
  },

}
