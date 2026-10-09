local map = vim.api.nvim_set_keymap

vim.opt.pumblend = 0

vim.diagnostic.config({
    underline = true,
    signs = true,
    update_in_insert = false,
    virtual_text = false,
    severity_sort = true,
})

vim.cmd [[autocmd! ColorScheme * highlight NormalFloat guibg=None]]
vim.cmd [[autocmd! ColorScheme * highlight FloatBorder guifg=white guibg=None]]

local function has_float_window()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.fn.win_gettype(win) == "popup" then
            return true
        end
    end
    return false
end

function open_float()
    if has_float_window() then
        return
    end
    vim.diagnostic.open_float(nil, {focus=false})
end

vim.o.updatetime = 250
vim.cmd [[autocmd CursorHold,CursorHoldI * lua open_float()]]

local border = {
      {"╭", "FloatBorder"},
      {"─", "FloatBorder"},
      {"╮", "FloatBorder"},
      {"│", "FloatBorder"},
      {"╯", "FloatBorder"},
      {"─", "FloatBorder"},
      {"╰", "FloatBorder"},
      {"│", "FloatBorder"},
}


local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts = opts or {}
  opts.border = opts.border or border
  return orig_util_open_floating_preview(contents, syntax, opts, ...)
end

return {
    {
        'neovim/nvim-lspconfig',

        config = function()
            -- keymap settings
            map('n', 'gd', '<cmd>FzfLua lsp_definitions<CR>', { noremap = true, silent = true })
            map('n', 'gr', '<cmd>FzfLua lsp_references<CR>', { noremap = true, silent = true })
            map('n', 'gi', '<cmd>FzfLua lsp_implementations<CR>', { noremap = true, silent = true })
            map('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', { noremap = true, silent = true })
            map('n', '<LEADER>a', '<cmd>FzfLua lsp_code_actions<CR>', { noremap = true, silent = true })
            map('n', '<LEADER>d', '<cmd>FzfLua lsp_document_diagnostics<CR>', { noremap = true, silent = true })
            map('n', '<LEADER>s', '<cmd>FzfLua lsp_live_workspace_symbols<CR>', { noremap = true, silent = true })
            map('n', '<LEADER>o', '<cmd>FzfLua lsp_document_symbols<CR>', { noremap = true, silent = true })
            map('n', '<LEADER>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', { noremap = true, silent = true })
            map('n', '<LEADER>f', '<cmd>FzfLua live_grep<CR>', { noremap = true, silent = true })

            --require('lspconfig').clangd.setup{
            --    filetypes = { "c", "cpp", "cuda" }
            --}
            --require('lspconfig').basedpyright.setup{}
            --require('lspconfig').rust_analyzer.setup{}
            --require('lspconfig').ruff.setup{}
            vim.lsp.config("clangd", {
                filetypes = { "c", "cpp", "cuda" },
            })
            
            vim.lsp.enable("clangd")
            
            vim.lsp.config("ty", {})
            vim.lsp.enable("ty")
            
            vim.lsp.config("rust_analyzer", {})
            vim.lsp.enable("rust_analyzer")
            
            vim.lsp.config("ruff", {})
            vim.lsp.enable("ruff")
        end,
    },
    
    {
        'hrsh7th/nvim-cmp',

        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "onsails/lspkind.nvim",
        },

        config = function()
            local cmp = require('cmp')
            cmp.setup({
                sources = {
                    { name = 'nvim_lsp' },
                    { name = 'buffer' },
                },
                mapping = cmp.mapping.preset.insert({
                    -- confirm completion
                    ['<cr>'] = cmp.mapping.confirm({select = true}),
                    ['<C-u>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-d>'] = cmp.mapping.scroll_docs(4),
                }),
                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                formatting = {
                    format = require('lspkind').cmp_format({
                        mode = 'symbol', -- show only symbol annotations
                        maxwidth = {
                            menu = 50, -- leading text (labelDetails)
                            abbr = 50, -- actual suggestion item
                        },
                        ellipsis_char = '...', -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)
                        show_labelDetails = true, -- show labelDetails in menu. Disabled by default
                        before = function (entry, vim_item)
                            return vim_item
                        end
                    })
                }
            })
        end
    },

    {'onsails/lspkind.nvim'},
}
