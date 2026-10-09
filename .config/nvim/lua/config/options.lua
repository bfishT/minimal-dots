local o = vim.o
local wo = vim.wo
local bo = vim.bo

local opt = vim.opt

-- buffer options

-- window options
wo.number = true
wo.relativenumber = true
wo.cursorline = true
wo.cursorlineopt = 'both'
wo.wrap = true
wo.foldmethod = 'indent'
wo.foldlevel = 99


-- global options
o.showcmd = true
o.wildmenu = true
o.hlsearch = true
o.ignorecase = true
o.smartcase = true
o.mouse = 'a'
o.scrolloff = 5
o.autochdir = true

o.tabstop = 4
o.shiftwidth = 0
o.softtabstop = -1

o.expandtab = true

o.autoindent = true

-- o.cmdheight = 0



-- Always show the signcolumn, otherwise it would shift the text each time
-- diagnostics appeared/became resolved
vim.opt.signcolumn = "yes"

vim.opt.scroll=10

vim.filetype.add({extension = { typ = 'typst' }})

vim.opt.signcolumn = "yes"
vim.opt.scroll = 10
--vim.opt.clipboard = "unnamedplus"

vim.opt.foldenable = true

local buffer_autoformat = function(bufnr)
  local group = 'lsp_autoformat'
  vim.api.nvim_create_augroup(group, {clear = false})
  vim.api.nvim_clear_autocmds({group = group, buffer = bufnr})

  vim.api.nvim_create_autocmd('BufWritePre', {
    buffer = bufnr,
    group = group,
    desc = 'LSP format on save',
    callback = function()
      -- note: do not enable async formatting
      local filetype = vim.bo[bufnr].filetype
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      if vim.tbl_contains({'c', 'cpp', 'cuda'}, filetype) then
        local filename = vim.api.nvim_buf_get_name(bufnr)
        local content = table.concat(lines, '\n')
        local formatted = vim.fn.system({
          'clang-format',
          '--assume-filename=' .. filename,
          '--style={BasedOnStyle: LLVM, IndentWidth: 4, UseTab: Never}',
        }, content)

        if vim.v.shell_error == 0 then
          lines = vim.split(formatted, '\n', {plain = true})
          if lines[#lines] == '' then
            table.remove(lines)
          end
        end
      else
        vim.lsp.buf.format({async = false, timeout_ms = 10000})
      end

      if filetype == 'cuda' then
        for i, line in ipairs(lines) do
          if line:match('^%s*#pragma') then
            local next_indent = line:match('^(%s*)')
            for j = i + 1, #lines do
              if not lines[j]:match('^%s*$') then
                next_indent = lines[j]:match('^(%s*)')
                break
              end
            end

            local new_line = next_indent .. line:gsub('^%s*', '')
            lines[i] = new_line
          end
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      elseif vim.tbl_contains({'c', 'cpp'}, filetype) then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      end
    end,
  })
end

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    local id = vim.tbl_get(event, 'data', 'client_id')
    local client = id and vim.lsp.get_client_by_id(id)
    if client == nil then
      return
    end

    -- make sure there is at least one client with formatting capabilities
    if client.supports_method('textDocument/formatting') then
      buffer_autoformat(event.buf)
    end
  end
})
