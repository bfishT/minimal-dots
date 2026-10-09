vim.g.python3_host_prog = vim.fn.exepath("python3")
vim.env.PATH = vim.fn.expand("~/.local/bin") .. ":" .. vim.env.PATH
require("config.lazy")
require("config.options")
require("config.keymaps")
