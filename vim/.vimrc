" =======================
" Vim .vimrc with fzf
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

" One Dark for Vim and Airline theme pack
Plug 'joshdick/onedark.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" fzf fuzzy finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" git and editing
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'sheerun/vim-polyglot'

call plug#end()

" =======================
" Theme and UI
" =======================
colorscheme onedark
let g:airline_powerline_fonts = 1
let g:airline_theme = 'onedark'

" =======================
" fzf search
" =======================
" requires ripgrep
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
