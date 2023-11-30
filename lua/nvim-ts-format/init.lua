local config = require("nvim-ts-format.configs")

local M = {}

M.formatexpr = function()
  return require("nvim-ts-format.format").format(vim.v.lnum, vim.v.count)
end

---@param opts TSFormatOpts
M.setup = function(opts)
  opts = opts and opts or {}

  
end

return M
