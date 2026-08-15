# shellcheck shell=bash
#
# zsh framework setup, shared by the Linux and macOS workstation scripts.
# Source lib/common.sh before this file.

_clone_if_missing() {
  local url="$1" dest="$2" name="$3"
  if [[ -d "$dest" ]]; then
    skip "${name} already installed"
  else
    info "Installing ${name}"
    try "${name} clone" run git clone --depth 1 "$url" "$dest"
  fi
}

# Installs oh-my-zsh, the plugins referenced by home/.zshrc and the
# spaceship prompt. Safe to re-run.
install_zsh_framework() {
  local omz="${ZSH:-${HOME}/.oh-my-zsh}"

  if [[ -d "$omz" ]]; then
    skip "oh-my-zsh already installed"
  else
    info "Installing oh-my-zsh"
    # KEEP_ZSHRC stops the installer from replacing our own .zshrc.
    try "oh-my-zsh install" run_sh \
      "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
  fi

  local custom="${ZSH_CUSTOM:-${omz}/custom}"
  [[ -d "$omz" ]] || return 0

  _clone_if_missing https://github.com/zsh-users/zsh-autosuggestions \
    "${custom}/plugins/zsh-autosuggestions" zsh-autosuggestions
  _clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting \
    "${custom}/plugins/zsh-syntax-highlighting" zsh-syntax-highlighting
  _clone_if_missing https://github.com/zsh-users/zsh-completions \
    "${custom}/plugins/zsh-completions" zsh-completions
  _clone_if_missing https://github.com/spaceship-prompt/spaceship-prompt.git \
    "${custom}/themes/spaceship-prompt" spaceship-prompt

  if [[ -d "${custom}/themes/spaceship-prompt" ]]; then
    run ln -sf "${custom}/themes/spaceship-prompt/spaceship.zsh-theme" \
      "${custom}/themes/spaceship.zsh-theme"
  fi
}

# Make zsh the login shell, registering it in /etc/shells when needed
# (Homebrew's zsh on macOS lives outside the default list).
set_default_shell_zsh() {
  has zsh || return 0
  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    skip "zsh is already the login shell"
    return 0
  fi

  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    run_sh "echo '${zsh_path}' | sudo tee -a /etc/shells >/dev/null"
  fi

  info "Setting zsh as the login shell"
  try "chsh" run sudo chsh -s "$zsh_path" "$CURRENT_USER"
}
