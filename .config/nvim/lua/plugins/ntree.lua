return {
    {
        'nvim-tree/nvim-tree.lua',

        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },

        keys = {
            {"tt", "<cmd>NvimTreeToggle<cr>", desc = "toggle nvim-tree"}
        },

        config = function()
            require("nvim-tree").setup({
                sort_by = "case_sensitive",
                view = {
                    adaptive_size = true,
                    --mappings = {
                    --    list = {
                    --        { key = "b", action = "dir_up" },
                    --        { key = "c", action = "<C-]"},
                    --        { key = "d", action = "remove"},
                    --        { key = "I", action = ""},
                    --        { key = "K", action = ""},
                    --        { key = "J", action = ""},
                    --        { key = "s", action = ""},
                    --        { key = "S", action = ""},
                    --        { key = "<C-h>", action = "toggle_git_ignore"}
                    --        -- { key = "I", action = "5i"},
                    --        -- { key = "K", action = "5k"}
                    --    },
                    --},
                },
                renderer = {
                    group_empty = true,
                },
                filters = {
                    dotfiles = true,
                },
                renderer = {
                    add_trailing = false,
                    group_empty = false,
                    highlight_git = false,
                    full_name = false,
                    highlight_opened_files = "none",
                    highlight_modified = "none",
                    root_folder_label = ":~:s?$?/..?",
                    indent_width = 2,
                    indent_markers = {
                        enable = false,
                        inline_arrows = true,
                        icons = {
                            corner = "└",
                            edge = "│",
                            item = "│",
                            bottom = "─",
                            none = " ",
                        },
                    },
                    icons = {
                        webdev_colors = true,
                        git_placement = "before",
                        modified_placement = "after",
                        padding = " ",
                        symlink_arrow = " ➛ ",
                        show = {
                            file = true,
                            folder = true,
                            folder_arrow = true,
                            git = true,
                            modified = true,
                        },
                        glyphs = {
                            default = "",
                            symlink = "",
                            bookmark = "",
                            modified = "●",
                            folder = {
                                arrow_closed = "",
                                arrow_open = "",
                                default = "",
                                open = "",
                                empty = "",
                                empty_open = "",
                                symlink = "",
                                symlink_open = "",
                            },
                            git = {
                                unstaged = "✗",
                                staged = "✓",
                                unmerged = "",
                                renamed = "➜",
                                untracked = "★",
                                deleted = "",
                                ignored = "◌",
                            },
                        },
                    },
                    special_files = { "Cargo.toml", "Makefile", "README.md", "readme.md" },
                    symlink_destination = true,
                }
            })
        end
    },

    {
        'nvim-tree/nvim-web-devicons',
    },

}
