local M = {}

M.formatexpr = function()
  return require("nvim-ts-format.format").format(vim.v.lnum, vim.v.count)
end

return M
