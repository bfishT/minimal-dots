return {
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        opts = {
            latex = { enabled = true },
        },
        config = function(_, opts)
            require("render-markdown").setup(opts)
            vim.opt.conceallevel = 2
            vim.opt.concealcursor = "nc"
        end,
    },
}
