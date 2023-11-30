
---@class (exact) TSFormatFtOpts
--- Whether each indent should be spaces or tabs. If nil, uses such filetype's `expandtab` to decide
---@field indent_type "spaces"|"tabs" 
--- How much should an indent be. If nil, it will be based on such filetype's default `shiftwidth`, or `tabstop` depending on `expandtab`
---@field indent_width integer 
--- maximum width per line. Currently unused
---@field max_width integer 

---@class TSFormatOpts
---@field default TSFormatFtOpts
---@field [string] TSFormatFtOpts filetype-specific settings


---@type TSFormatOpts
local default_config = {
  default = {
    indent_width = 2,
    indent_type = "spaces",
    max_width = 120,
  }
}

local config = vim.deepcopy(default_config)

local M = {}

---@param opts TSFormatOpts
function M.update(opts)
  config = vim.tbl_deep_extend("force", config, opts)
end

setmetatable(M, {
  __index = function (_, k)
    return config[k]
  end
})

return M
