set nocompatible
syntax on
filetype plugin indent on

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

autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
autocmd FileType java   setlocal tabstop=4 shiftwidth=4 expandtab
autocmd FileType rust   setlocal tabstop=4 shiftwidth=4 expandtab

set ignorecase
set smartcase
set incsearch
set hlsearch

set hidden
set wildmenu
set scrolloff=5
set splitbelow splitright

let mapleader=" "

nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader><space> :nohlsearch<CR>

nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi

call plug#begin('~/.vim/plugged')
Plug 'preservim/nerdtree'
Plug 'vim-airline/vim-airline'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'sheerun/vim-polyglot'
call plug#end()


