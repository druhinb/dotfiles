" =======================
" Vim .vimrc with fzf, One Dark, and refined Airline
" =======================

set nocompatible
set encoding=utf-8
set termguicolors
set number
set relativenumber
set cursorline
set showmatch
set clipboard=unnamedplus

set expandtab
set shiftwidth=4
set tabstop=4
set smartindent
set autoindent

set ignorecase
set smartcase
set incsearch
set hlsearch

set hidden
set wildmenu
set scrolloff=5
set splitbelow
set splitright
set signcolumn=yes

let mapleader=" "

augroup IndentPerFT
  autocmd!
  autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
  autocmd FileType java   setlocal tabstop=4 shiftwidth=4 expandtab
  autocmd FileType rust   setlocal tabstop=4 shiftwidth=4 expandtab
augroup END

nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader><space> :nohlsearch<CR>
nnoremap <M-j> :m .+1<CR>==
nnoremap <M-k> :m .-2<CR>==

" =======================
" Plugins via vim-plug
" =======================
call plug#begin('~/.vim/plugged')

Plug 'joshdick/onedark.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'sheerun/vim-polyglot'
Plug 'airblade/vim-gitgutter'

call plug#end()

" =======================
" Theme and Airline
" =======================
colorscheme onedark
let g:airline_powerline_fonts = 1
let g:airline_theme = 'onedark'

let g:airline_left_sep  = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif
let g:airline_symbols.space     = nr2char(0x00A0)
let g:airline_symbols.branch    = ''
let g:airline_symbols.readonly  = ''
let g:airline_symbols.linenr    = ''
let g:airline_symbols.maxlinenr = '☰'
let g:airline_symbols.dirty     = ''
set ambiwidth=single

let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'
let g:airline#extensions#tabline#buffer_nr_show = 1
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#hunks#enabled = 1
let g:airline#extensions#whitespace#enabled = 1
let g:airline#extensions#whitespace#mixed_indent_algo = 2

" =======================
" fzf search
" =======================
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case
  command! -nargs=* Rg silent grep <args> | copen
  let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow --glob "!.git/*"'
endif

nnoremap <leader>ff :Files<CR>
nnoremap <leader>fg :Rg<Space>
nnoremap <leader>fb :Buffers<CR>
nnoremap <leader>fh :Helptags<CR>
nnoremap <leader>fo :History<CR>

" make unix the default line ending
set fileformats=unix,dos

let g:airline_section_z = '%3p%% | %l:%c'
