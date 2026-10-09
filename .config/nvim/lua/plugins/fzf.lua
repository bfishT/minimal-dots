return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    winopts = {
      -- 透明度，值 0~100，越大越不透明，0 完全透明
      winblend = 0,
      -- 如果想更透明，winblend 值可以调小一点，比如 10
    },
  },
  config = function(_, opts)
    require("fzf-lua").setup(opts)

    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("TransparentFzfLua", { clear = true }),
        callback = function()
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
            vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
        end,
    })
  end,
}

