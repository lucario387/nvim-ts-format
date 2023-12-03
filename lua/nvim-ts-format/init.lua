local M = {}

M.formatexpr = function()
  return require("nvim-ts-format.format").format(vim.v.lnum, vim.v.count)
end


---@param bufnr integer
M.format_buf = function(bufnr)
  require("nvim-ts-format.format").format_buf(bufnr)
end

return M
