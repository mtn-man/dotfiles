let mapleader = " "

syntax on
filetype plugin indent on
set number
set backspace=indent,eol,start
set incsearch
set hlsearch
set clipboard=unnamed
set mouse=a
set ignorecase smartcase
set hidden
set tabstop=4 shiftwidth=4 expandtab softtabstop=4

autocmd FileType go setlocal noexpandtab tabstop=4 shiftwidth=4

inoremap jk <Esc>
nnoremap <silent> <Esc> :nohlsearch<CR>
nnoremap <leader>h :bprevious<CR>
nnoremap <leader>l :bnext<CR>
nnoremap <leader>x :bdelete<CR>
