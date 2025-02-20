local actions = require("aerial.actions")
local util = require("aerial.util")
local M = {}

local function resolve(rhs)
  if type(rhs) == "string" and vim.startswith(rhs, "actions.") then
    return resolve(actions[vim.split(rhs, ".", true)[2]])
  elseif type(rhs) == "table" then
    local opts = vim.deepcopy(rhs)
    opts.callback = nil
    return rhs.callback, opts
  end
  return rhs, {}
end

M.set_keymaps = function(mode, keymaps, bufnr)
  for k, v in pairs(keymaps) do
    local rhs, opts = resolve(v)
    if rhs then
      vim.keymap.set(mode, k, rhs, vim.tbl_extend("keep", { buffer = bufnr }, opts))
    end
  end
end

M.show_help = function(keymaps)
  local rhs_to_lhs = {}
  local lhs_to_all_lhs = {}
  for k, rhs in pairs(keymaps) do
    if rhs then
      if rhs_to_lhs[rhs] then
        local first_lhs = rhs_to_lhs[rhs]
        table.insert(lhs_to_all_lhs[first_lhs], k)
      else
        rhs_to_lhs[rhs] = k
        lhs_to_all_lhs[k] = { k }
      end
    end
  end

  local col_left = {}
  local col_desc = {}
  local max_lhs = 1
  for k, rhs in pairs(keymaps) do
    local all_lhs = lhs_to_all_lhs[k]
    if all_lhs then
      local _, opts = resolve(rhs)
      local keystr = table.concat(all_lhs, "/")
      max_lhs = math.max(max_lhs, vim.api.nvim_strwidth(keystr))
      table.insert(col_left, { str = keystr, all_lhs = all_lhs })
      table.insert(col_desc, opts.desc or "")
    end
  end

  local lines = {}
  local highlights = {}
  local max_line = 1
  for i = 1, #col_left do
    local left = col_left[i]
    local desc = col_desc[i]
    local line = string.format(" %s   %s", util.rpad(left.str, max_lhs), desc)
    max_line = math.max(max_line, vim.api.nvim_strwidth(line))
    table.insert(lines, line)
    local start = 1
    for _, key in ipairs(left.all_lhs) do
      local keywidth = vim.api.nvim_strwidth(key)
      table.insert(highlights, { "Special", #lines, start, start + keywidth })
      start = start + keywidth + 1
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local ns = vim.api.nvim_create_namespace("AerialKeymap")
  for _, hl in ipairs(highlights) do
    local hl_group, lnum, start_col, end_col = unpack(hl)
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, start_col, {
      end_col = end_col,
      hl_group = hl_group,
    })
  end
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = bufnr })
  vim.keymap.set("n", "<c-c>", "<cmd>close<CR>", { buffer = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight
  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.max(0, (editor_height - #lines) / 2),
    col = math.max(0, (editor_width - max_line - 1) / 2),
    width = math.min(editor_width, max_line + 1),
    height = math.min(editor_height, #lines),
    zindex = 150,
    style = "minimal",
    border = "rounded",
  })
end

return M
