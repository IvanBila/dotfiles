# ------------------------ Variables -------------------------
export ZSH="/home/ux/.oh-my-zsh"
ZSH_THEME="gallois"

export UPDATE_ZSH_DAYS=5
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
plugins=(git zsh-autosuggestions)



# ------------------------ Sourcing -------------------------
source $ZSH/oh-my-zsh.sh



# ------------------------ Aliases -------------------------

# Git
alias gs='git status'
alias ga='git add'
alias gp="git push"
alias gpl="git pull"
alias gc="git checkout"
alias gcm="git checkout master && git pull"
alias wip='git add . && git commit -m"WIP"'
alias gd='git diff'

 
# Laravel
alias art='php artisan'
alias phpunit='vendor/bin/phpunit'
alias cda='composer dump-autoload -o'
alias mmo='php artisan make:model'
alias ms='php artisan make:seed'
alias mpr='php artisan make:provider'
alias rl='php artisan route:list'
alias phinx='./vendor/bin/phinx'

# Clis
alias js='node'
