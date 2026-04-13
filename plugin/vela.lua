-- plugin/vela.lua
-- Loaded automatically by Neovim's plugin loader.
-- Only runs setup if the user hasn't already called require("vela").setup().

if vim.g.vela_loaded then return end
vim.g.vela_loaded = true

-- Guard: don't run in headless/non-interactive mode (e.g. CI)
if vim.fn.argc(-1) == 0 and not vim.g.vela_force_load then
  -- Defer to the FileType autocmd rather than loading everything eagerly
  return
end
