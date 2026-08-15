" ~/.vimrc

set nocompatible
filetype off

if filereadable(expand('~/.vim/plugins.vim'))
  source ~/.vim/plugins.vim
endif

filetype plugin indent on
syntax enable

let mapleader = ','

"-------------------- General ------------------"
set encoding=utf-8
set fileformats=unix,dos,mac
set hidden                      " keep unsaved buffers around
set autoread                    " reload files changed outside vim
set history=1000
set undofile                    " persistent undo, across sessions
set undodir=~/.vim/undo//
set directory=~/.vim/swap//
set backupdir=~/.vim/backup//
set nobackup nowritebackup
set ttimeoutlen=10              " no lag leaving insert mode
set mouse=a
set clipboard^=unnamed,unnamedplus
set splitbelow splitright
set modelines=5                 " needed by ~/.git-commit-template.txt

silent! call mkdir(expand('~/.vim/undo'), 'p')
silent! call mkdir(expand('~/.vim/swap'), 'p')
silent! call mkdir(expand('~/.vim/backup'), 'p')

"-------------------- Visuals ------------------"
set number
set relativenumber
set cursorline
set showmatch
set scrolloff=5
set sidescrolloff=5
set signcolumn=yes
set laststatus=2
set wildmenu
set wildmode=longest:full,full
set wildignore+=*/node_modules/*,*/vendor/*,*/.git/*,*/dist/*,*.pyc

if has('termguicolors') && $COLORTERM =~# 'truecolor\|24bit'
  set termguicolors
endif

set background=dark
silent! colorscheme seoul256

"-------------------- Indentation ------------------"
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4
set shiftround
set smartindent
set autoindent
set backspace=indent,eol,start

autocmd FileType javascript,typescript,json,html,css,scss,yaml,vim
      \ setlocal tabstop=2 softtabstop=2 shiftwidth=2
autocmd FileType make,go setlocal noexpandtab

"-------------------- Searching ------------------"
set hlsearch
set incsearch
set ignorecase
set smartcase                   " case-sensitive once you type a capital

" Use ripgrep for :grep when it is available.
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

"-------------------- Mappings ------------------"
nmap <Leader>ev :e ~/.vimrc<cr>
nmap <Leader>pl :e ~/.vim/plugins.vim<cr>
nmap <Leader><space> :nohlsearch<cr>

" Buffers and tabs
nmap <Leader>p :tabprevious<cr>
nmap <Leader>n :tabnext<cr>
nmap <Leader>e :tabedit<space>
nmap <Leader>c :tabclose<cr>
nmap <Leader>b :Buffers<cr>

" Files and content (fzf)
nmap <C-p> :Files<cr>
nmap <C-r> :BTags<cr>
nmap <Leader>f :Rg<space>
nmap <Leader>g :GFiles<cr>

" Write and quit without the shift key gymnastics
nmap <Leader>w :w<cr>
nmap <Leader>q :q<cr>

" Move between splits
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Keep the cursor centred when jumping through search results
nnoremap n nzzzv
nnoremap N Nzzzv

" Move visual selections up and down
vnoremap J :m '>+1<cr>gv=gv
vnoremap K :m '<-2<cr>gv=gv

" Stay in visual mode when indenting
vnoremap < <gv
vnoremap > >gv

" Write a file that needed sudo
cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit!

" Git (fugitive)
nmap <Leader>gs :Git<cr>
nmap <Leader>gb :Git blame<cr>
nmap <Leader>gd :Gdiffsplit<cr>

"------ Auto Commands ------"

augroup autosourcing
  autocmd!
  autocmd BufWritePost .vimrc source %
augroup END

augroup restore_cursor
  autocmd!
  " Reopen a file at the line you left it on.
  autocmd BufReadPost *
        \ if line("'\"") > 0 && line("'\"") <= line("$") | execute "normal! g`\"" | endif
augroup END

augroup trailing_whitespace
  autocmd!
  " Highlight trailing whitespace, except while typing it.
  autocmd InsertEnter * match none
  autocmd InsertLeave * match ErrorMsg /\s\+$/
augroup END

"------ PHP ------"

function! IPhpExpandClass()
  call PhpExpandClass()
  call feedkeys('a', 'n')
endfunction

autocmd FileType php inoremap <Leader>n <Esc>:call IPhpExpandClass()<CR>
autocmd FileType php noremap <Leader>n :call PhpExpandClass()<CR>
