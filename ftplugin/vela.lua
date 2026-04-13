-- ftplugin/vela.lua
-- Buffer-local settings applied to every .vela buffer.

local opt = vim.opt_local

-- Indentation: 2 spaces (SFC convention)
opt.expandtab   = true
opt.shiftwidth  = 2
opt.softtabstop = 2
opt.tabstop     = 2

-- Wrap at word boundaries (template content can be long)
opt.linebreak   = true

-- Enable spell check in comment/string regions only (via treesitter spell)
-- opt.spell = true  -- uncomment if you want spell checking

-- Comment string for the template section (<!-- --> style)
-- Depends on which section the cursor is in; set a sensible default.
opt.commentstring = "<!-- %s -->"

-- Folding: fold by indent works well for SFCs
opt.foldmethod = "indent"
opt.foldlevel  = 99  -- open all folds by default

-- Match HTML-style tags with %
opt.matchpairs:append("<:>")

-- ─────────────────────────────────────────────
--  Keymaps (buffer-local)
-- ─────────────────────────────────────────────

local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = true, desc = desc, silent = true })
end

-- Jump between SFC sections
map("n", "]s", function() require("vela.nav").next_section() end, "Next SFC section")
map("n", "[s", function() require("vela.nav").prev_section() end, "Prev SFC section")

-- Open the compiled .js file side-by-side
map("n", "<leader>vj", function() require("vela.nav").open_compiled() end, "Open compiled JS")

-- Trigger LSP restart for this buffer
map("n", "<leader>vr", "<cmd>VelaRestartLsp<cr>", "Restart Vela LSP")
