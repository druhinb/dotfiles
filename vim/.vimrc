" =======================
" Vim .vimrc with fzf, One Dark, Airline, and enhanced Git


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
set fileformats=unix,dos

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
" Plugins
" =======================
call plug#begin()

Plug 'liuchengxu/vim-which-key'
Plug 'joshdick/onedark.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'            " Gbrowse on GitHub and similar
Plug 'airblade/vim-gitgutter'
Plug 'junegunn/gv.vim'              " commit browser
Plug 'rhysd/conflict-marker.vim'    " merge conflict highlighting

Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'sheerun/vim-polyglot'

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
if !exists('g:airline_symbols') | let g:airline_symbols = {} | endif
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
" keep right edge compact
let g:airline_section_z = '%3p%% | %l:%c'

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

" =======================
" Git enhancements
" =======================
" gitgutter signs and navigation
let g:gitgutter_sign_added = '▎'
let g:gitgutter_sign_modified = '▎'
let g:gitgutter_sign_removed = '▁'
let g:gitgutter_sign_removed_first_line = '▔'
let g:gitgutter_sign_modified_removed = '▎'
let g:gitgutter_max_signs = 2000
nnoremap ]h <Plug>(GitGutterNextHunk)
nnoremap [h <Plug>(GitGutterPrevHunk)
nnoremap <leader>hs <Plug>(GitGutterStageHunk)
nnoremap <leader>hr <Plug>(GitGutterUndoHunk)
nnoremap <leader>hp <Plug>(GitGutterPreviewHunk)

" fugitive core
nnoremap <leader>gs :G<CR>
nnoremap <leader>gd :Gdiffsplit<CR>
nnoremap <leader>gb :G blame<CR>
nnoremap <leader>gr :Gread<CR>
nnoremap <leader>gw :Gwrite<CR>
nnoremap <leader>gc :G commit<CR>
nnoremap <leader>gP :G push<CR>
nnoremap <leader>go :Gbrowse<CR>

" fzf powered git pickers
nnoremap <leader>g? :GFiles?<CR>
nnoremap <leader>gf :GFiles<CR>
nnoremap <leader>gl :Commits<CR>
nnoremap <leader>gL :BCommits<CR>
nnoremap <leader>gt :BTags<CR>

" commit browser
nnoremap <leader>gv :GV<CR>
nnoremap <leader>gV :GV!<CR>

" merge conflict helpers
let g:conflict_marker_enable_mappings = 0
nnoremap <leader>cn :ConflictMarkerNextHunk<CR>
nnoremap <leader>cN :ConflictMarkerPrevHunk<CR>
nnoremap <leader>co :ConflictMarkerOurselves<CR>
nnoremap <leader>ct :ConflictMarkerThemselves<CR>

set timeoutlen=300
nnoremap <silent> <leader> :WhichKey '<Space>'<CR>
