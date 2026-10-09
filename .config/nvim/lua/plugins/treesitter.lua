return {
    'nvim-treesitter/nvim-treesitter',
    config = function()
        require'nvim-treesitter.configs'.setup {
            -- 安装 language parser
            -- :TSInstallInfo 命令查看支持的语言
            ensure_installed = {"vim", "lua", "c", "cpp", "rust", "java", "python", "racket", "c_sharp", "css", "html", "typescript", "javascript", "latex", "markdown"},
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false
            },
            incremental_selection = {
                enable = false,
                keymaps = {
                    init_selection = '<CR>',
                    node_incremental = '<CR>',
                    node_decremental = '<BS>',
                    scope_incremental = '<TAB>',
                },
            },
            indent = {
                enable = true
            }
        }
        -- 开启 Folding
        vim.wo.foldmethod = 'expr'
        vim.wo.foldexpr = 'nvim_treesitter#foldexpr()'

    end
}


