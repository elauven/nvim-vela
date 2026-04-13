-- lua/vela/nav.lua
-- Navigation helpers for .vela single-file components.

local M = {}

-- ─────────────────────────────────────────────
--  Section jumping
-- ─────────────────────────────────────────────

local section_tags = { "script", "style", "template" }

---Find the line numbers of each SFC section opening tag.
---@param bufnr? number defaults to current buffer
---@return table<string, number>  section name → 0-indexed line
local function find_sections(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local found = {}
  for i, line in ipairs(lines) do
    for _, tag in ipairs(section_tags) do
      if line:match("^<" .. tag .. "[>%s]") then
        found[tag] = i - 1  -- 0-indexed
      end
    end
  end
  return found
end

---Jump to the next SFC section (wraps around).
function M.next_section()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1] - 1  -- 0-indexed
  local sections = find_sections()

  -- Collect section lines, sorted ascending
  local lines = {}
  for _, tag in ipairs(section_tags) do
    if sections[tag] then
      table.insert(lines, { tag = tag, line = sections[tag] })
    end
  end
  table.sort(lines, function(a, b) return a.line < b.line end)

  -- Find the next section after the cursor
  for _, s in ipairs(lines) do
    if s.line > current_line then
      vim.api.nvim_win_set_cursor(0, { s.line + 1, 0 })
      vim.notify("→ <" .. s.tag .. ">", vim.log.levels.INFO, { title = "Vela" })
      return
    end
  end
  -- Wrap to first
  if #lines > 0 then
    vim.api.nvim_win_set_cursor(0, { lines[1].line + 1, 0 })
    vim.notify("→ <" .. lines[1].tag .. "> (wrapped)", vim.log.levels.INFO, { title = "Vela" })
  end
end

---Jump to the previous SFC section (wraps around).
function M.prev_section()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1] - 1
  local sections = find_sections()

  local lines = {}
  for _, tag in ipairs(section_tags) do
    if sections[tag] then
      table.insert(lines, { tag = tag, line = sections[tag] })
    end
  end
  table.sort(lines, function(a, b) return a.line > b.line end)  -- descending

  for _, s in ipairs(lines) do
    if s.line < current_line then
      vim.api.nvim_win_set_cursor(0, { s.line + 1, 0 })
      vim.notify("← <" .. s.tag .. ">", vim.log.levels.INFO, { title = "Vela" })
      return
    end
  end
  -- Wrap to last
  if #lines > 0 then
    vim.api.nvim_win_set_cursor(0, { lines[1].line + 1, 0 })
    vim.notify("← <" .. lines[1].tag .. "> (wrapped)", vim.log.levels.INFO, { title = "Vela" })
  end
end

-- ─────────────────────────────────────────────
--  Open compiled JS
-- ─────────────────────────────────────────────

---Open the compiled .js counterpart of the current .vela file.
---Looks in common output dirs: dist/, out/, build/, .
function M.open_compiled()
  local fname = vim.api.nvim_buf_get_name(0)
  if not fname:match("%.vela$") then
    vim.notify("Not a .vela file", vim.log.levels.WARN)
    return
  end

  local dir  = vim.fn.fnamemodify(fname, ":h")
  local base = vim.fn.fnamemodify(fname, ":t:r")  -- filename without extension

  -- Search strategy: walk up looking for dist/out/build, then try sibling .js
  local root  = vim.fs.find({ "package.json", ".git" }, { path = dir, upward = true })[1]
  local root_dir = root and vim.fn.fnamemodify(root, ":h") or dir

  -- Compute relative path from root
  local rel = fname:sub(#root_dir + 2)             -- e.g. "src/components/Badge.vela"
  local rel_js = rel:gsub("%.vela$", ".js")        -- e.g. "src/components/Badge.js"

  local candidates = {
    root_dir .. "/dist/" .. rel_js,
    root_dir .. "/out/"  .. rel_js,
    root_dir .. "/build/".. rel_js,
    dir .. "/" .. base .. ".js",
  }

  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then
      -- Open in vertical split
      vim.cmd("vsplit " .. vim.fn.fnameescape(path))
      vim.notify("Compiled: " .. vim.fn.fnamemodify(path, ":~:."), vim.log.levels.INFO)
      return
    end
  end

  vim.notify(
    "Compiled JS not found. Run the compiler first:\n  vela --project src --out dist",
    vim.log.levels.WARN
  )
end

-- ─────────────────────────────────────────────
--  Which section is the cursor in?
-- ─────────────────────────────────────────────

---Return the name of the SFC section the cursor is currently in.
---@return string "script"|"style"|"template"|"unknown"
function M.current_section()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line   = cursor[1] - 1
  local sections = find_sections()

  -- Find the deepest section start before the cursor
  local result = "unknown"
  local best   = -1
  for tag, start_line in pairs(sections) do
    if start_line <= line and start_line > best then
      best   = start_line
      result = tag
    end
  end
  return result
end

return M
