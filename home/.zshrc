# ~/.zshrc — interactive zsh configuration.
#
# Layout:
#   ~/.exports     environment and PATH (also used by bash)
#   ~/.aliases     aliases
#   ~/.functions   functions
#   ~/.zshrc.local machine-specific overrides, never committed
#
# Nothing here assumes a tool is installed: every integration is guarded, so
# this file works on a bare machine and gets better as tooling appears.

# ---------------------------------------------------------------------------
# Environment (before oh-my-zsh, so plugins see the right PATH)
# ---------------------------------------------------------------------------

[[ -f "${HOME}/.exports" ]] && source "${HOME}/.exports"

# ---------------------------------------------------------------------------
# oh-my-zsh
# ---------------------------------------------------------------------------

export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="spaceship"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

ENABLE_CORRECTION="false"        # autocorrect fights with git subcommands
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"   # keeps the prompt fast in large repos
HIST_STAMPS="yyyy-mm-dd"

plugins=(
  git
  docker
  docker-compose
  kubectl
  npm
  node
  composer
  laravel
  golang
  rust
  python
  pip
  terraform
  aws
  tmux
  fzf
  direnv
  command-not-found
  colored-man-pages
  extract
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting        # must stay last
)

# Only load plugins that are actually present, or oh-my-zsh warns on startup.
for _plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -d "${ZSH_CUSTOM:-${ZSH}/custom}/plugins/${_plugin}" ]] ||
    plugins=("${(@)plugins:#${_plugin}}")
done
unset _plugin

if [[ -f "${ZSH}/oh-my-zsh.sh" ]]; then
  source "${ZSH}/oh-my-zsh.sh"
fi

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------

SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_CHAR_SYMBOL="❯ "
SPACESHIP_PROMPT_ORDER=(
  dir           # current directory
  git           # branch and status
  package       # package version
  node          # Node.js
  php           # PHP
  golang        # Go
  rust          # Rust
  python        # Python / virtualenv
  ruby          # Ruby
  java          # Java
  docker        # Docker context
  kubectl       # Kubernetes context
  terraform     # Terraform workspace
  aws           # AWS profile
  exec_time     # duration of the last command
  line_sep      # line break
  jobs          # background jobs
  exit_code     # non-zero exit codes
  char          # prompt character
)
SPACESHIP_EXEC_TIME_ELAPSED=3          # only show slow commands
SPACESHIP_DIR_TRUNC=3
SPACESHIP_KUBECTL_SHOW=false           # noisy unless you are mid-deploy

# Fall back to a usable prompt if spaceship is not installed yet.
if [[ ! -f "${ZSH_CUSTOM:-${ZSH}/custom}/themes/spaceship.zsh-theme" ]]; then
  autoload -Uz vcs_info
  precmd() { vcs_info }
  zstyle ':vcs_info:git:*' formats ' (%b)'
  setopt PROMPT_SUBST
  PROMPT='%F{blue}%~%f%F{yellow}${vcs_info_msg_0_}%f
%(?.%F{green}.%F{red})❯%f '
fi

# ---------------------------------------------------------------------------
# zsh options
# ---------------------------------------------------------------------------

setopt AUTO_CD                 # `cd` is implied by a bare directory name
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt EXTENDED_GLOB
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

# History: shared across sessions, deduplicated, timestamped.
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE       # a leading space keeps a command out of history
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY             # expand !! before running it

# Completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${HOME}/.cache/zsh/zcompcache"

# ---------------------------------------------------------------------------
# Key bindings
# ---------------------------------------------------------------------------

bindkey -e                                    # emacs bindings
bindkey '^[[A' history-search-backward         # up arrow searches the prefix
bindkey '^[[B' history-search-forward
bindkey '^[[1;5C' forward-word                 # ctrl-right
bindkey '^[[1;5D' backward-word                # ctrl-left
bindkey '^[[3~' delete-char
bindkey '^H' backward-kill-word

# Edit the current command line in $EDITOR with ctrl-x ctrl-e.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ---------------------------------------------------------------------------
# Aliases and functions
# ---------------------------------------------------------------------------

[[ -f "${HOME}/.aliases" ]] && source "${HOME}/.aliases"
[[ -f "${HOME}/.functions" ]] && source "${HOME}/.functions"

# ---------------------------------------------------------------------------
# Tool integrations (each one guarded)
# ---------------------------------------------------------------------------

# nvm — lazily loaded: sourcing it eagerly costs ~500ms on every new shell.
if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  nvm() {
    unset -f nvm node npm npx yarn pnpm 2>/dev/null
    source "${NVM_DIR}/nvm.sh"
    [[ -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"
    nvm "$@"
  }
  for _cmd in node npm npx yarn pnpm; do
    # shellcheck disable=SC2139
    eval "${_cmd}() { unset -f nvm node npm npx yarn pnpm 2>/dev/null; \
      source '${NVM_DIR}/nvm.sh'; ${_cmd} \"\$@\"; }"
  done
  unset _cmd
  # Respect a project's .nvmrc when entering a directory.
  autoload -U add-zsh-hook
  _load_nvmrc() {
    [[ -f .nvmrc ]] && nvm use --silent 2>/dev/null
  }
  add-zsh-hook chpwd _load_nvmrc
fi

# SDKMAN (Java, Maven, Gradle) — must be near the end per its own docs.
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"

command -v rbenv >/dev/null 2>&1 && eval "$(rbenv init - zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --alias)"

# fzf key bindings: ctrl-t (files), ctrl-r (history), alt-c (cd).
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)                       # fzf >= 0.48
  else
    [[ -f "${HOME}/.fzf.zsh" ]] && source "${HOME}/.fzf.zsh"
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] &&
      source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] &&
      source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# Completions for tools that generate their own.
_dotfiles_completions="${HOME}/.cache/zsh/completions"
if [[ ! -d "$_dotfiles_completions" ]]; then
  command mkdir -p "$_dotfiles_completions"
  command -v kubectl >/dev/null 2>&1 && kubectl completion zsh >"${_dotfiles_completions}/_kubectl"
  command -v helm >/dev/null 2>&1 && helm completion zsh >"${_dotfiles_completions}/_helm"
  command -v gh >/dev/null 2>&1 && gh completion -s zsh >"${_dotfiles_completions}/_gh"
  command -v terraform >/dev/null 2>&1 && terraform -install-autocomplete 2>/dev/null
fi
fpath=("$_dotfiles_completions" $fpath)
unset _dotfiles_completions

autoload -Uz compinit
# Rebuild the completion cache once a day instead of on every shell start.
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# ---------------------------------------------------------------------------
# Machine-specific overrides (secrets, work config, one-off PATH entries)
# ---------------------------------------------------------------------------

[[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
