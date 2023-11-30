

require("nvim-treesitter.configs").setup({
  auto_install = true,
  ensure_installed = { "markdown_inline" },
})

vim.api.nvim_create_user_command("FormatFile", function()
  require("nvim-ts-format.format").format_buf()
end, {})
