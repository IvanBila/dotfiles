set nocompatible
filetype on

source ~/.vim/plugins.vim

syntax enable
set number
set backspace=indent,eol,start
set smartindent
set autoindent
set showmatch

let mapleader = ','

"-------------------- Viusals ------------------"
"colorscheme gruvbox"
"colorscheme atom-dark-256"
colorscheme seoul256
"color dracula"


"-------------------- Mappings ------------------"
 nmap ,ev :e ~/.vimrc<cr>
 nmap ,pl :e ~/.vim/plugins.vim<cr>
 nmap <Leader><space> :nohlsearch<cr>
 nmap <c-R> :CtrlPBufTag<cr>
 nmap <Leader>p :tabprevious<cr>
 nmap <Leader>n :tabnext<cr>
 nmap <Leader>e :tabedit 
 nmap <Leader>c :tabclose<cr>
 

"---------- Searching ---------"
set hlsearch
set incsearch


"------ Auto Commands ------"

"Automatically source the vimrc file on save"
augroup autosourcing
    autocmd!
    autocmd BufWritePost .vimrc source %
augroup END


function! IPhpExpandClass()
    call PhpExpandClass()
    call feedkeys('a', 'n')
endfunction
autocmd FileType php inoremap <Leader>n <Esc>:call IPhpExpandClass()<CR>
autocmd FileType php noremap <Leader>n :call PhpExpandClass()<CR>
