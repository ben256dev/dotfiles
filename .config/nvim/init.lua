-- Options
vim.opt.termguicolors = true
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.ttimeoutlen = 0
vim.opt.showmode = false

vim.g.mapleader = ' '
vim.g.python_highlight_all = 1
vim.g.markdown_fenced_languages = {
  'bash=sh', 'sh', 'python', 'c', 'cpp', 'json', 'html', 'javascript', 'typescript',
}

-- Pure black instead of onedark's grey (dark mode, non-transparent only).
local black_background = {
  Normal = { bg = '#000000' },
  NonText = { bg = '#000000' },
  EndOfBuffer = { bg = '#000000' },
  SignColumn = { bg = '#000000' },
}

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
require('lazy').setup({

  -- Colorscheme
  {
    'navarasu/onedark.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('onedark').setup({
        style = 'dark',
        transparent = false,
        term_colors = true,
        ending_tildes = false,
        code_style = {
          comments = 'italic',
        },
        highlights = black_background,
      })
      require('onedark').load()
    end,
  },

  -- C3 syntax highlighting (the upstream runtime lives under vim/).
  {
    'c3lang/editor-plugins',
    lazy = false,
    config = function(plugin)
      vim.opt.rtp:append(plugin.dir .. '/vim')
      vim.filetype.add({
        extension = { c3 = 'c3', c3i = 'c3', c3t = 'c3' },
      })
    end,
  },

  -- LSP + Completion
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      -- Every server gets nvim-cmp's completion capabilities.
      vim.lsp.config('*', { capabilities = require('cmp_nvim_lsp').default_capabilities() })

      -- c3-lsp crashes on a file with no project root (a loose .c3 file), so
      -- only start it inside a C3 project or git repo.
      vim.lsp.config('c3', {
        cmd = { 'c3-lsp' },
        filetypes = { 'c3' },
        root_dir = function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, { 'project.json', 'manifest.json', '.git' })
          if root then
            on_dir(root)
          end
        end,
      })

      -- Godot's language server is a TCP port that only exists while the Godot
      -- editor is open. Check the port first, so a closed editor means no LSP
      -- instead of a connection error. If you open Godot after the file, :e it.
      local godot_port = tonumber(os.getenv('GDScript_Port') or '6005')
      vim.lsp.config('gdscript', {
        root_dir = function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, { 'project.godot', '.git' })
          local probe = vim.uv.new_tcp()
          probe:connect('127.0.0.1', godot_port, function(err)
            probe:close()
            if not err then
              on_dir(root)
            end
          end)
        end,
      })

      -- Enable each server only when its binary is installed.
      local servers = {
        clangd = 'clangd',
        pyright = 'pyright-langserver',
        gopls = 'gopls',
        ts_ls = 'typescript-language-server',
        c3 = 'c3-lsp',
      }
      for server, executable in pairs(servers) do
        if vim.fn.executable(executable) == 1 then
          vim.lsp.enable(server)
        end
      end
      vim.lsp.enable('gdscript')

      local cmp = require('cmp')
      local luasnip = require('luasnip')
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
        }, {
          { name = 'buffer' },
          { name = 'path' },
        }),
      })
    end,
  },

  -- Formatting
  {
    'stevearc/conform.nvim',
    opts = {
      formatters_by_ft = {
        gdscript = { 'gdformat' },
      },
      format_after_save = {
        timeout_ms = 2000,
        lsp_format = 'never',
      },
    },
  },

  -- Statusline
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = {
          theme = 'onedark',
          section_separators = '',
          component_separators = '',
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = { 'filename' },
          lualine_x = { function() return 'Type Space then ? for help' end },
          lualine_y = {},
          lualine_z = { 'progress', 'location' },
        },
        tabline = {
          lualine_a = { 'buffers' },
          lualine_z = { 'tabs' },
        },
      })
    end,
  },

  -- Color preview
  {
    'NvChad/nvim-colorizer.lua',
    config = function()
      require('colorizer').setup({
        user_default_options = {
          mode = 'background',
        },
      })
    end,
  },

  -- Misc plugins
  { 'junegunn/vim-easy-align' },
  { 'tpope/vim-fugitive' },
  { 'junegunn/fzf', build = ':call fzf#install()' },
  { 'junegunn/fzf.vim' },
  { 'tpope/vim-repeat' },
})

-- nvim-lspconfig defers to Neovim's built-in :lsp command on 0.12+, which
-- means its usual :LspInfo alias is not created.
if vim.fn.exists(':LspInfo') == 0 then
  vim.api.nvim_create_user_command('LspInfo', 'checkhealth vim.lsp', {
    desc = 'Show LSP configuration and client status',
  })
end

-- Keybindings: Skeletons
local skeletons = vim.fn.stdpath('config') .. '/skeletons'
vim.keymap.set('n', ',c',     ':-1read ' .. skeletons .. '/skeleton.c<CR>4j$')
vim.keymap.set('n', ',sh',    ':-1read ' .. skeletons .. '/skeleton.sh<CR>:w<CR>:e<CR>2j')
vim.keymap.set('n', ',html',  ':-1read ' .. skeletons .. '/skeleton.html<CR>4jf>l')
vim.keymap.set('n', ',mainc', ':-1read ' .. skeletons .. '/skeleton.mainc<CR>')
vim.keymap.set('n', ',go',    ':-1read ' .. skeletons .. '/skeleton.go<CR>4j$')
vim.keymap.set('n', ',py',    ':-1read ' .. skeletons .. '/skeleton.py<CR>:w<CR>:e<CR>2j')
vim.keymap.set('n', ',c3',    ':-1read ' .. skeletons .. '/skeleton.c3<CR>4j$')

-- Keybindings: Brace/tag helpers
vim.keymap.set('i', ',fi', '{<CR>}<Esc>O')
vim.keymap.set('i', ',if', '{<CR>}<Esc>O')
vim.keymap.set('i', '><', '<ESC>a><ESC>bi<<ESC>yf>a/<ESC>hP')

-- Keybindings: FZF
vim.keymap.set('n', '<Leader>b',  ':Buffers<CR>')
vim.keymap.set('n', '<Leader>f',  ':Files<CR>')
vim.keymap.set('n', '<Leader>g',  ':GFiles<CR>')
vim.keymap.set('n', '<Leader>h:', ':History:<CR>')
vim.keymap.set('n', '<Leader>h/', ':History/<CR>')
vim.keymap.set('n', '<Leader>H:', 'q:')
vim.keymap.set('n', '<Leader>H/', 'q/')

-- Keybindings: Window navigation. Ctrl-w then m/n/e/i, the same direction keys
-- as tmux panes (prefix m/n/e/i) and bspwm windows (super + m/n/e/i).
-- This replaces Vim's rarely used Ctrl-w n (new window) and Ctrl-w i (split to
-- definition); Ctrl-w h/j/k/l still work.
vim.keymap.set('n', '<C-w>m', '<C-w>h', { desc = 'Window left' })
vim.keymap.set('n', '<C-w>n', '<C-w>j', { desc = 'Window down' })
vim.keymap.set('n', '<C-w>e', '<C-w>k', { desc = 'Window up' })
vim.keymap.set('n', '<C-w>i', '<C-w>l', { desc = 'Window right' })

-- Keybindings: Browser-style buffer navigation
vim.keymap.set({ 'n', 'i', 'x' }, '<C-Tab>', '<Cmd>bnext<CR>', {
  desc = 'Move to the next buffer',
})
vim.keymap.set({ 'n', 'i', 'x' }, '<C-S-Tab>', '<Cmd>bprevious<CR>', {
  desc = 'Move to the previous buffer',
})
-- Legacy terminals may report Ctrl-Tab as Tab and Ctrl-Shift-Tab as Shift-Tab.
-- Those terminals also send Ctrl-I as Tab, so there Ctrl-I (jump forward)
-- switches buffers instead.
vim.keymap.set('n', '<Tab>', '<Cmd>bnext<CR>', {
  desc = 'Move to the next buffer',
})
vim.keymap.set('n', '<S-Tab>', '<Cmd>bprevious<CR>', {
  desc = 'Move to the previous buffer',
})

-- Keybindings: Cheatsheet
vim.keymap.set('n', '<leader>?', function()
  local cheatsheet = vim.fn.stdpath('config') .. '/CHEATSHEET.md'
  vim.cmd('split ' .. vim.fn.fnameescape(cheatsheet))
  vim.bo.bufhidden = 'wipe'
end, { desc = 'Open Neovim cheatsheet' })

-- Keybindings: EasyAlign
vim.keymap.set('x', 'ga', '<Plug>(EasyAlign)')
vim.keymap.set('n', 'ga', '<Plug>(EasyAlign)')

-- Color toggles: transparent background, light/dark
vim.g.transparent_bg = false
vim.g.light_mode = false

local function apply_color_mode()
  local onedark = require('onedark')
  local style = vim.g.light_mode and 'light' or 'dark'

  onedark.set_options('style', style)
  onedark.set_options('transparent', vim.g.transparent_bg)
  onedark.set_options(
    'highlights',
    not vim.g.light_mode and not vim.g.transparent_bg and black_background or {}
  )
  vim.opt.background = vim.g.light_mode and 'light' or 'dark'
  onedark.load()
end

local function toggle_transparent_bg()
  vim.g.transparent_bg = not vim.g.transparent_bg
  apply_color_mode()
end

local function toggle_light_mode()
  vim.g.light_mode = not vim.g.light_mode
  apply_color_mode()
end

vim.keymap.set('n', '<leader>tt', toggle_transparent_bg, { desc = 'Toggle transparent background' })
vim.keymap.set('n', '<leader>ll', toggle_light_mode, { desc = 'Toggle light / dark colors' })

-- Autocommands (grouped so re-sourcing this file doesn't duplicate them).
-- Go and GDScript tab settings come from Neovim's own ftplugins.
local augroup = vim.api.nvim_create_augroup('user_config', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  pattern = { 'html', 'text' },
  callback = function()
    vim.opt_local.wrap = false
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  pattern = { 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.breakindent = true
  end,
})
