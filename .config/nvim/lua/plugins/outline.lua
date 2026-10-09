return {
    {
        "hedyhli/outline.nvim",
        config = function()
          vim.keymap.set("n", "<leader>O", "<cmd>Outline<CR>",
            { desc = "Toggle Outline" })

          require("outline").setup {
            -- Your setup opts here (leave empty to use defaults)
            outline_window = {
                border = "rounded",   -- 边框样式
                max_width = 40,       -- 最大宽度
                min_width = 20,       -- 最小宽度
            },
          }
        end,
    },

}
