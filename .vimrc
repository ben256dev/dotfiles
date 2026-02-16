set termguicolors
let g:python_highlight_all=1
let g:vim_json_syntax_conceal=0
let g:markdown_fenced_languages=['bash=sh','sh','python','c','cpp','json','html','javascript','typescript']
syntax on
filetype plugin indent on

let g:onedark_hide_endofbuffer=1
let g:onedark_termcolors=256
let g:onedark_terminal_italics=1
augroup onedark_overrides
  autocmd!
  autocmd ColorScheme onedark highlight Normal ctermbg=0 guibg=#000000
augroup END
colorscheme onedark

set relativenumber
set number
set tabstop=4
set shiftwidth=4
set expandtab
set hlsearch
set incsearch

let mapleader = " "

" Normal Mode Snippets
autocmd FileType html,markdown,md,txt setlocal nowrap
nnoremap ,c :-1read $HOME/.vim/.skeleton.c<CR>4j$
nnoremap ,sh :-1read $HOME/.vim/.skeleton.sh<CR>:w<CR>:e<CR>2j
nnoremap ,html :-1read $HOME/.vim/.skeleton.html<CR>4jf>l
nnoremap ,mainc :-1read $HOME/.vim/.skeleton.mainc<CR>
nnoremap ,go :-1read $HOME/.vim/.skeleton.go<CR>4j$

" Braces and tags helpers
inoremap ,fi {<CR>}<Esc>O
inoremap ,if {<CR>}<Esc>O
inoremap >< <ESC>a><ESC>bi<<ESC>yf>a/<ESC>hP

" DISABLED in favor of tmux copy mode
" Copy to clipboard
" vnoremap <C-c> "zy:call system('wl-copy', @z)<CR>

" Plug-in keybindings
nnoremap <Leader>b  :Buffers<CR>
nnoremap <Leader>f  :Files<CR>
nnoremap <Leader>g  :GFiles<CR>
nnoremap <Leader>h: :History:<CR>
nnoremap <Leader>h/ :History/<CR>
nnoremap <Leader>H: q:
nnoremap <Leader>H/ q/

" Switch between vim windows
nnoremap <C-Left>  <C-w>h
nnoremap <C-Down>  <C-w>j
nnoremap <C-Up>    <C-w>e
nnoremap <C-Right> <C-w>l

call plug#begin('~/.vim/plugged')
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  Plug 'junegunn/vim-easy-align'
  Plug 'tpope/vim-fugitive'
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  Plug 'tpope/vim-repeat'
  Plug 'github/copilot.vim'
  Plug 'rrethy/vim-hexokinase', { 'do': 'make hexokinase' }
call plug#end()

let g:Hexokinase_highlighters = ['backgroundfull']

augroup dart_hot_reload
    autocmd!
    autocmd BufWritePost *.dart silent! CocCommand flutter.dev.hotReload
augroup END

xmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)

let g:airline_section_x = ''
let g:airline_section_y = ''
let g:airline_section_z = '%p%% %l:%c'

let g:airline_theme = 'onedark'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'


set laststatus=2
set ttimeoutlen=0
set noshowmode

let g:transparent_bg = 0

function! ToggleTransparentBG()
  if g:transparent_bg
    set background=dark
    highlight Normal ctermbg=0 guibg=#000000
    highlight NonText ctermbg=0 guibg=#000000
    highlight EndOfBuffer ctermbg=0 guibg=#000000
    highlight SignColumn ctermbg=0 guibg=#000000
  else
    highlight Normal ctermbg=NONE guibg=NONE
    highlight NonText ctermbg=NONE guibg=NONE
    highlight EndOfBuffer ctermbg=NONE guibg=NONE
    highlight SignColumn ctermbg=NONE guibg=NONE
  endif
  let g:transparent_bg = !g:transparent_bg
endfunction

" Toggle transparent background
nnoremap <leader>tt :call ToggleTransparentBG()<CR>
let g:health_sites = {
\       'ben256.com': 'https://ben256.com/health',
\      'audioma.com': 'https://audioma.app/health',
\    'nightdiff.com': 'https://nightdiff.review/health',
\       'shthub.com': 'https://shthub.org/health',
\ 'lamangatacos.com': 'https://lamangatacos.com/health',
\ }

let g:health_status = {}
let g:health_fail = {}
let g:health_need = 3
let g:health_interval_ms = 120000

let g:health_icon_up = ''
let g:health_icon_down = '󱘥'

function! HealthIcon(s)
  return a:s ==# 'up' ? g:health_icon_up : g:health_icon_down
endfunction

let g:health_full = {
\       'ben256.com': 'ben256.com',
\      'audioma.com': 'audioma.app',
\    'nightdiff.com': 'nightdiff.review',
\       'shthub.com': 'shthub.org',
\ 'lamangatacos.com': 'lamangatacos.com',
\ }

let g:health_naked = {
\       'ben256.com': 'ben256',
\      'audioma.com': 'audioma',
\    'nightdiff.com': 'nightdiff',
\       'shthub.com': 'shthub',
\ 'lamangatacos.com': 'lamangatacos',
\ }

let g:health_short = {
\       'ben256.com': 'ben256',
\      'audioma.com': 'audioma',
\    'nightdiff.com': 'diff',
\       'shthub.com': 'sht',
\ 'lamangatacos.com': 'tacos',
\ }

function! HealthLine()
  let cols = &columns

  if cols >= 100
    let mode = 0
  elseif cols >= 80
    let mode = 1
  elseif cols >= 60
    let mode = 2
  else
    let mode = 3
  endif

  let out = []
  for [k, _] in items(g:health_sites)
    let s = get(g:health_status, k, '?')
    if mode == 0
      call add(out, get(g:health_full, k, k) . ' ' . HealthIcon(s))
    elseif mode == 1
      call add(out, get(g:health_naked, k, k) . ' ' . HealthIcon(s))
    elseif mode == 2
      call add(out, get(g:health_short, k, k) . ' ' . HealthIcon(s))
    else
      call add(out, HealthIcon(s))
    endif
  endfor

  return join(sort(out), '  ')
endfunction

function! HealthExit(name, job, status)
  let ok = (a:status == 0)
  if ok
    let g:health_fail[a:name] = 0
    let g:health_status[a:name] = 'up'
  else
    let g:health_fail[a:name] = get(g:health_fail, a:name, 0) + 1
    if g:health_fail[a:name] >= g:health_need
      let g:health_status[a:name] = 'down'
    endif
  endif

  if exists('*airline#update_statusline')
    call airline#update_statusline()
  else
    redrawstatus
  endif
endfunction

function! PollHealth(timer)
  for [name, url] in items(g:health_sites)
    call job_start(['curl','-fsS','--max-time','3',url], {'exit_cb': function('HealthExit', [name])})
  endfor
endfunction

call PollHealth(0)
call timer_start(g:health_interval_ms, 'PollHealth', {'repeat': -1})

let g:airline_section_y = '%{HealthLine()}'
