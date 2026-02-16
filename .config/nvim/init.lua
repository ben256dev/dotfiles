-- Options
vim.opt.termguicolors = true
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.laststatus = 2
vim.opt.ttimeoutlen = 0
vim.opt.showmode = false

vim.g.mapleader = ' '
vim.g.python_highlight_all = 1
vim.g.vim_json_syntax_conceal = 0
vim.g.markdown_fenced_languages = {
  'bash=sh', 'sh', 'python', 'c', 'cpp', 'json', 'html', 'javascript', 'typescript',
}

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
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
        highlights = {
          Normal = { bg = '#000000' },
          NonText = { bg = '#000000' },
          EndOfBuffer = { bg = '#000000' },
          SignColumn = { bg = '#000000' },
        },
      })
      require('onedark').load()
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
      local lspconfig = require('lspconfig')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      lspconfig.clangd.setup({ capabilities = capabilities })
      lspconfig.pyright.setup({ capabilities = capabilities })
      lspconfig.gopls.setup({ capabilities = capabilities })
      lspconfig.ts_ls.setup({ capabilities = capabilities })

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
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
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
          lualine_x = {},
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

  -- Kept plugins
  { 'junegunn/vim-easy-align' },
  { 'tpope/vim-fugitive' },
  { 'junegunn/fzf', build = ':call fzf#install()' },
  { 'junegunn/fzf.vim' },
  { 'tpope/vim-repeat' },
  { 'github/copilot.vim' },
})

-- Keybindings: Skeletons
local skeletons = vim.fn.stdpath('config') .. '/skeletons'
vim.keymap.set('n', ',c',     ':-1read ' .. skeletons .. '/skeleton.c<CR>4j$')
vim.keymap.set('n', ',sh',    ':-1read ' .. skeletons .. '/skeleton.sh<CR>:w<CR>:e<CR>2j')
vim.keymap.set('n', ',html',  ':-1read ' .. skeletons .. '/skeleton.html<CR>4jf>l')
vim.keymap.set('n', ',mainc', ':-1read ' .. skeletons .. '/skeleton.mainc<CR>')
vim.keymap.set('n', ',go',    ':-1read ' .. skeletons .. '/skeleton.go<CR>4j$')

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

-- Keybindings: Window navigation
vim.keymap.set('n', '<C-Left>',  '<C-w>h')
vim.keymap.set('n', '<C-Down>',  '<C-w>j')
vim.keymap.set('n', '<C-Up>',    '<C-w>k')
vim.keymap.set('n', '<C-Right>', '<C-w>l')

-- Keybindings: EasyAlign
vim.keymap.set('x', 'ga', '<Plug>(EasyAlign)')
vim.keymap.set('n', 'ga', '<Plug>(EasyAlign)')

-- Transparent background toggle
vim.g.transparent_bg = false

local function toggle_transparent_bg()
  if vim.g.transparent_bg then
    require('onedark').load()
    vim.api.nvim_set_hl(0, 'Normal',      { bg = '#000000' })
    vim.api.nvim_set_hl(0, 'NonText',     { bg = '#000000' })
    vim.api.nvim_set_hl(0, 'EndOfBuffer', { bg = '#000000' })
    vim.api.nvim_set_hl(0, 'SignColumn',  { bg = '#000000' })
  else
    vim.api.nvim_set_hl(0, 'Normal',      { bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'NonText',     { bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'EndOfBuffer', { bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'SignColumn',  { bg = 'NONE' })
  end
  vim.g.transparent_bg = not vim.g.transparent_bg
end

vim.keymap.set('n', '<leader>tt', toggle_transparent_bg)

-- Autocommands
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'html', 'markdown', 'text' },
  callback = function()
    vim.opt_local.wrap = false
  end,
})
