" Plugins, managed by vim-plug (installed by ../install.sh).
"   :PlugInstall  install    :PlugUpdate  update    :PlugClean  remove unused

call plug#begin('~/.vim/plugged')

" --- Interface -------------------------------------------------------------
Plug 'itchyny/lightline.vim'            " status line
Plug 'mhinz/vim-startify'               " start screen with recent files
Plug 'junegunn/seoul256.vim'            " colourscheme (current)
Plug 'morhetz/gruvbox'                  " colourscheme
Plug 'dracula/vim', { 'as': 'dracula' } " colourscheme

" --- Navigation ------------------------------------------------------------
Plug 'tpope/vim-vinegar'                " netrw, made usable
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'                 " :Files :Rg :Buffers :Commits

" --- Editing ---------------------------------------------------------------
Plug 'tpope/vim-surround'               " cs\"' to change surrounding quotes
Plug 'tpope/vim-commentary'             " gcc to comment a line
Plug 'tpope/vim-repeat'                 " make . work with the plugins above
Plug 'jiangmiao/auto-pairs'             " close brackets and quotes
Plug 'mg979/vim-visual-multi'           " multiple cursors
Plug 'editorconfig/editorconfig-vim'    " honour .editorconfig

" --- Git -------------------------------------------------------------------
Plug 'tpope/vim-fugitive'               " :Git blame, :Gdiffsplit
Plug 'airblade/vim-gitgutter'           " change markers in the sign column

" --- Languages & tooling ---------------------------------------------------
Plug 'dense-analysis/ale'               " linting and fixing (async)
Plug 'sheerun/vim-polyglot'             " syntax for ~100 languages
Plug 'StanAngeloff/php.vim'
Plug 'arnaud-lb/vim-php-namespace'      " PhpExpandClass, used in ~/.vimrc
Plug 'mattn/emmet-vim'                  " HTML/CSS abbreviations
Plug 'skywind3000/asyncrun.vim'         " run builds and tests in the background

call plug#end()

" --- Plugin configuration ---------------------------------------------------

" lightline shows the mode, so vim does not need to.
set noshowmode
let g:lightline = { 'colorscheme': 'seoul256' }

" ALE: lint on save only, and fix on save where a fixer exists.
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_enter = 0
let g:ale_fix_on_save = 1
let g:ale_sign_error = '>>'
let g:ale_sign_warning = '--'
let g:ale_fixers = {
      \ '*':          ['remove_trailing_lines', 'trim_whitespace'],
      \ 'javascript': ['prettier', 'eslint'],
      \ 'typescript': ['prettier', 'eslint'],
      \ 'json':       ['prettier'],
      \ 'css':        ['prettier'],
      \ 'html':       ['prettier'],
      \ 'yaml':       ['prettier'],
      \ 'php':        ['php_cs_fixer'],
      \ 'python':     ['ruff', 'black'],
      \ 'go':         ['gofmt', 'goimports'],
      \ 'rust':       ['rustfmt'],
      \ 'sh':         ['shfmt'],
      \ }

" fzf: search file contents with ripgrep.
let g:fzf_layout = { 'down': '40%' }

" gitgutter: update the signs quickly without hammering the disk.
set updatetime=250
let g:gitgutter_map_keys = 0
