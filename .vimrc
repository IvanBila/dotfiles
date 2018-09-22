
set nocompatible

so ~/.vim/plugins.vim

syntax enable
set number
set backspace=indent,eol,start
let mapleader = ','

"-------------------- Viusals ------------------"
colorscheme atom-dark-256
"-------------------- Mappings ------------------"
 nmap ,ev :e ~/.vimrc<cr>
 nmap <Leader><space> :nohlsearch<cr>
 nmap <c-R> :CtrlPBufTag<cr>

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


