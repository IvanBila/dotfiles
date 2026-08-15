#!/usr/bin/env bash
#
# Link the dotfiles in home/ into $HOME.
#
# Anything under home/ is mirrored into $HOME at the same relative path, so
# home/.vim/plugins.vim becomes ~/.vim/plugins.vim. Existing real files are
# moved into a timestamped backup directory before being replaced.
#
#   ./install.sh                 link dotfiles
#   ./install.sh --packages      link, then run the workstation setup for this OS
#   ./install.sh --dry-run       show what would change

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${DOTFILES_DIR}/lib/common.sh"

BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
RUN_PACKAGES=false
ASSUME_YES=false
LINKED=0 SKIPPED=0 BACKED_UP=0

usage() {
  cat <<EOF
${C_BOLD}install.sh${C_RESET} — link the dotfiles into \$HOME

Usage: $(basename "$0") [options] [-- <setup script options>]

Options:
  --packages     Also run setup-linux-workstation.sh / setup-macos-workstation.sh
  --dry-run      Print what would change without touching the filesystem
  -y, --yes      Assume yes for all prompts
  -h, --help     Show this help

Any options after -- are forwarded to the workstation setup script, e.g.
  ./install.sh --packages -- --only docker,node
EOF
}

SETUP_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages)
      RUN_PACKAGES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -y | --yes)
      ASSUME_YES=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      SETUP_ARGS=("$@")
      break
      ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
done

# ---------------------------------------------------------------------------
# Linking
# ---------------------------------------------------------------------------

backup() {
  local target="$1" rel="$2"
  local dest="${BACKUP_DIR}/${rel}"
  info "Backing up existing ${rel} -> ${dest}"
  run mkdir -p "$(dirname "$dest")"
  run mv "$target" "$dest"
  BACKED_UP=$((BACKED_UP + 1))
}

link_file() {
  local src="$1" rel="$2"
  local target="${HOME}/${rel}"

  if [[ -L "$target" ]]; then
    if [[ "$(readlink "$target")" == "$src" ]]; then
      skip "${rel} already linked"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    run rm -f "$target"
  elif [[ -e "$target" ]]; then
    backup "$target" "$rel"
  fi

  run mkdir -p "$(dirname "$target")"
  run ln -sfn "$src" "$target"
  success "${rel} -> ${src#"${DOTFILES_DIR}/"}"
  LINKED=$((LINKED + 1))
}

link_dotfiles() {
  header "Linking dotfiles"
  local src rel
  while IFS= read -r -d '' src; do
    rel="${src#"${DOTFILES_DIR}/home/"}"
    link_file "$src" "$rel"
  done < <(find "${DOTFILES_DIR}/home" -type f -print0 | sort -z)
}

# ---------------------------------------------------------------------------
# Local, machine-specific configuration
# ---------------------------------------------------------------------------

# home/.gitconfig deliberately contains no identity: it includes
# ~/.gitconfig.local, which stays off the repository.
write_gitconfig_local() {
  local local_config="${HOME}/.gitconfig.local"
  if [[ -f "$local_config" ]]; then
    skip "${local_config} already exists"
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%s  would create:%s %s\n' "$C_DIM" "$C_RESET" "$local_config"
    return 0
  fi

  local name email signingkey
  if [[ "$ASSUME_YES" == "true" ]]; then
    name="$(git config --global user.name || true)"
    email="$(git config --global user.email || true)"
    signingkey=""
  else
    header "Git identity (written to ~/.gitconfig.local, never committed)"
    read -r -p "Full name: " name
    read -r -p "Email: " email
    read -r -p "GPG signing key (blank to disable commit signing): " signingkey
  fi

  {
    printf '# Machine-local git configuration. Not tracked by the dotfiles repo.\n'
    printf '[user]\n'
    printf '\tname = %s\n' "$name"
    printf '\temail = %s\n' "$email"
    if [[ -n "$signingkey" ]]; then
      printf '\tsigningkey = %s\n' "$signingkey"
      printf '[commit]\n\tgpgsign = true\n'
      printf '[tag]\n\tgpgsign = true\n'
    fi
  } >"$local_config"
  success "wrote ${local_config}"
}

setup_vim() {
  local plug="${HOME}/.vim/autoload/plug.vim"
  if [[ -f "$plug" ]]; then
    skip "vim-plug already installed"
  else
    info "Installing vim-plug"
    run mkdir -p "${HOME}/.vim/autoload"
    try "vim-plug download" run_sh \
      "curl -fsSL --retry 3 -o '${plug}' https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
  fi
  if has vim && [[ -f "$plug" && "$DRY_RUN" != "true" ]]; then
    info "Installing vim plugins"
    try "vim PlugInstall" run vim -Es -u "${HOME}/.vimrc" +PlugInstall +qall
  fi
}

prepare_dirs() {
  local dir
  for dir in "${HOME}/.local/bin" "${HOME}/.config" "${HOME}/.cache" "${HOME}/Projects"; do
    [[ -d "$dir" ]] || run mkdir -p "$dir"
  done
}

run_setup_script() {
  local script
  if is_macos; then
    script="${DOTFILES_DIR}/setup-macos-workstation.sh"
  elif is_linux; then
    script="${DOTFILES_DIR}/setup-linux-workstation.sh"
  else
    die "Unsupported platform: $(uname -s)"
  fi
  header "Running $(basename "$script")"
  local args=("${SETUP_ARGS[@]+"${SETUP_ARGS[@]}"}")
  [[ "$DRY_RUN" == "true" ]] && args+=(--dry-run)
  [[ "$ASSUME_YES" == "true" ]] && args+=(--yes)
  bash "$script" "${args[@]+"${args[@]}"}"
}

main() {
  info "Dotfiles: ${DOTFILES_DIR}"
  [[ "$DRY_RUN" == "true" ]] && warn "dry run — no changes will be made"

  prepare_dirs
  link_dotfiles
  write_gitconfig_local
  setup_vim

  header "Summary"
  success "${LINKED} linked, ${SKIPPED} already current, ${BACKED_UP} backed up"
  [[ $BACKED_UP -gt 0 ]] && info "Backups in ${BACKUP_DIR}"

  if [[ "$RUN_PACKAGES" == "true" ]]; then
    run_setup_script
  else
    info "Run './install.sh --packages' (or the setup script directly) to install tooling"
  fi

  printf '\nStart a new shell to pick up the changes: %sexec zsh%s\n' "$C_BOLD" "$C_RESET"
}

main "$@"
