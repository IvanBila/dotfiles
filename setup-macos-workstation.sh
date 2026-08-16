#!/usr/bin/env bash
#
# Provision a macOS development workstation.
#
# Every module is idempotent: re-running the script installs what is missing
# and leaves everything else alone.
#
#   ./setup-macos-workstation.sh                    # everything except system defaults
#   ./setup-macos-workstation.sh --only docker,node
#   ./setup-macos-workstation.sh --minimal          # core CLI only, no casks or extras
#   ./setup-macos-workstation.sh --defaults         # also apply the macOS system defaults
#   ./setup-macos-workstation.sh --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/shell.sh
source "${SCRIPT_DIR}/lib/shell.sh"

MODULES=(core brew extras casks shell docker node python java rust defaults)

# macOS still ships bash 3.2, which has no associative arrays: `declare -A`
# there is parsed as an indexed array and dies on the first subscript with
# "core: unbound variable". This script is what installs a newer bash in the
# first place, so it has to run on the stock one — hence a lookup function.
module_desc() {
  case "$1" in
    core) printf '%s' "Xcode Command Line Tools, Rosetta 2 and Homebrew" ;;
    brew) printf '%s' "Core CLI toolchain from packages/Brewfile" ;;
    extras) printf '%s' "Cloud, Kubernetes, platform CLIs and database tooling from packages/Brewfile.extras" ;;
    casks) printf '%s' "GUI applications and Nerd Fonts from packages/Brewfile.casks" ;;
    shell) printf '%s' "oh-my-zsh, spaceship prompt, autosuggestions, syntax highlighting" ;;
    docker) printf '%s' "Container runtime (Colima by default, or Docker Desktop)" ;;
    node) printf '%s' "nvm, Node.js LTS, corepack (yarn/pnpm) and global CLIs" ;;
    python) printf '%s' "pipx-managed Python tooling (poetry, ruff, black, pre-commit)" ;;
    java) printf '%s' "SDKMAN with the current Java LTS, Maven and Gradle" ;;
    rust) printf '%s' "rustup, cargo, clippy, rustfmt" ;;
    defaults) printf '%s' "Opinionated macOS system defaults (opt-in via --defaults)" ;;
    *) printf '%s' "$1" ;;
  esac
}

# `defaults` mutates system preferences, so it is opt-in rather than opt-out.
SKIP_MODULES="defaults"
ONLY_MODULES="" ASSUME_YES=false
DOCKER_DESKTOP=false

usage() {
  cat <<EOF
${C_BOLD}setup-macos-workstation.sh${C_RESET} — provision a macOS dev machine

Usage: $(basename "$0") [options]

Options:
  --only <a,b,c>    Run only these modules
  --skip <a,b,c>    Run everything except these modules
  --list            List available modules and exit
  --minimal         Core CLI only (skip extras, casks)
  --no-casks        Skip GUI applications and fonts
  --docker-desktop  Install Docker Desktop instead of Colima
  --defaults        Also apply the macOS system defaults in macos/defaults.sh
  --dry-run         Print what would happen without changing anything
  -y, --yes         Assume yes for all prompts
  -h, --help        Show this help
EOF
}

list_modules() {
  printf '%sAvailable modules%s\n' "$C_BOLD" "$C_RESET"
  local m
  for m in "${MODULES[@]}"; do
    printf '  %-9s %s\n' "$m" "$(module_desc "$m")"
  done
}

add_skip() { SKIP_MODULES="${SKIP_MODULES:+${SKIP_MODULES},}$1"; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only)
        ONLY_MODULES="${2:?--only needs a value}"
        shift 2
        ;;
      --skip)
        add_skip "${2:?--skip needs a value}"
        shift 2
        ;;
      --list)
        list_modules
        exit 0
        ;;
      --minimal)
        add_skip "extras,casks"
        shift
        ;;
      --no-casks)
        add_skip "casks"
        shift
        ;;
      --docker-desktop)
        DOCKER_DESKTOP=true
        shift
        ;;
      --defaults)
        SKIP_MODULES="${SKIP_MODULES//defaults/}"
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
      *) die "Unknown option: $1 (try --help)" ;;
    esac
  done
}

brew_bin() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '/opt/homebrew/bin/brew'
  elif [[ -x /usr/local/bin/brew ]]; then
    printf '/usr/local/bin/brew'
  else
    command -v brew || return 1
  fi
}

load_brew_env() {
  local brew
  brew="$(brew_bin 2>/dev/null || true)"
  [[ -n "$brew" ]] || return 1
  eval "$("$brew" shellenv)"
}

# brew_bundle <Brewfile> — install a bundle, reporting what is missing first.
brew_bundle() {
  local file="${SCRIPT_DIR}/packages/$1"
  [[ -f "$file" ]] || {
    warn "missing ${file}"
    return 0
  }
  if brew bundle check --file "$file" >/dev/null 2>&1; then
    skip "$1 already satisfied"
    return 0
  fi
  info "Installing from $1 (this can take a while)"
  run brew bundle install --file "$file" --no-upgrade || warn "$1 had failures"
}

# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------

module_core() {
  if xcode-select -p >/dev/null 2>&1; then
    skip "Xcode Command Line Tools already installed"
  else
    info "Installing Xcode Command Line Tools"
    run xcode-select --install || true
    info "Waiting for the Command Line Tools installation to finish..."
    until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  fi

  if is_arm64 && ! /usr/bin/pgrep -q oahd; then
    info "Installing Rosetta 2"
    try "rosetta install" run softwareupdate --install-rosetta --agree-to-license
  fi

  if brew_bin >/dev/null 2>&1; then
    skip "Homebrew already installed"
  else
    info "Installing Homebrew"
    run_sh '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' ||
      die "Homebrew installation failed"
  fi

  load_brew_env || die "Homebrew is installed but not on PATH"
  try "brew update" run brew update
}

module_brew() {
  load_brew_env || die "Homebrew not found; run the core module first"
  brew_bundle Brewfile
}

module_extras() {
  load_brew_env || return 0
  brew_bundle Brewfile.extras
}

module_casks() {
  load_brew_env || return 0
  brew_bundle Brewfile.casks
}

module_shell() {
  load_brew_env || true
  install_zsh_framework
  set_default_shell_zsh
}

module_docker() {
  load_brew_env || return 0

  if [[ "$DOCKER_DESKTOP" == "true" ]]; then
    if [[ -d "/Applications/Docker.app" ]]; then
      skip "Docker Desktop already installed"
    else
      info "Installing Docker Desktop"
      try "docker desktop install" run brew install --cask docker-desktop
    fi
    info "Launch Docker.app once to finish setup and start the engine"
    return 0
  fi

  has colima || try "colima install" run brew install colima docker docker-compose docker-buildx

  # Buildx and Compose ship as CLI plugins; Homebrew installs them outside the
  # directory the docker CLI scans, so link them in.
  run mkdir -p "${HOME}/.docker/cli-plugins"
  local plugin
  for plugin in docker-buildx docker-compose; do
    if [[ -x "$(brew --prefix)/bin/${plugin}" && ! -e "${HOME}/.docker/cli-plugins/${plugin}" ]]; then
      run ln -sfn "$(brew --prefix)/bin/${plugin}" "${HOME}/.docker/cli-plugins/${plugin}"
    fi
  done

  if has colima && ! colima status >/dev/null 2>&1; then
    info "Starting the Colima VM (4 CPUs, 8GiB RAM, 60GiB disk)"
    try "colima start" run colima start --cpu 4 --memory 8 --disk 60
  else
    skip "colima already running"
  fi
}

module_node() {
  local nvm_dir="${NVM_DIR:-${HOME}/.nvm}"
  run mkdir -p "$nvm_dir"
  if [[ -s "${nvm_dir}/nvm.sh" ]]; then
    skip "nvm already installed"
  else
    info "Installing nvm"
    try "nvm install" run_sh \
      "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | PROFILE=/dev/null bash"
  fi

  [[ "$DRY_RUN" == "true" ]] && return 0
  [[ -s "${nvm_dir}/nvm.sh" ]] || {
    warn "nvm not available; skipping Node.js"
    return 0
  }

  # nvm's own scripts are not written for `set -euo pipefail`.
  set +eu
  # shellcheck disable=SC1091
  . "${nvm_dir}/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
  if command -v corepack >/dev/null 2>&1; then
    corepack enable
    corepack prepare yarn@stable pnpm@latest --activate
  fi
  # Deploy CLIs (vercel, firebase, heroku, eas) come from Brewfile.extras.
  npm install -g npm@latest typescript ts-node tsx eslint prettier \
    serve nodemon npm-check-updates
  set -eu
}

module_python() {
  load_brew_env || true
  has pipx || {
    warn "pipx not installed; run the brew module first"
    return 0
  }

  run pipx ensurepath >/dev/null 2>&1 || true
  local tool
  for tool in poetry ruff black mypy pre-commit ipython virtualenv; do
    if pipx list --short 2>/dev/null | grep -q "^${tool} "; then
      skip "pipx ${tool} already installed"
    else
      try "pipx install ${tool}" run pipx install "$tool"
    fi
  done
}

module_java() {
  local sdkman_dir="${SDKMAN_DIR:-${HOME}/.sdkman}"
  if [[ -s "${sdkman_dir}/bin/sdkman-init.sh" ]]; then
    skip "SDKMAN already installed"
  else
    info "Installing SDKMAN"
    try "SDKMAN install" run_sh "curl -s https://get.sdkman.io?rcupdate=false | bash"
  fi

  [[ "$DRY_RUN" == "true" ]] && return 0
  [[ -s "${sdkman_dir}/bin/sdkman-init.sh" ]] || return 0

  set +eu
  # shellcheck disable=SC1091
  . "${sdkman_dir}/bin/sdkman-init.sh"
  sdk install java </dev/null
  sdk install maven </dev/null
  sdk install gradle </dev/null
  set -eu
}

module_rust() {
  if has rustup || [[ -x "${HOME}/.cargo/bin/rustup" ]]; then
    skip "rustup already installed"
  else
    info "Installing rustup"
    try "rustup install" run_sh \
      "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
  fi
  if [[ -x "${HOME}/.cargo/bin/rustup" ]]; then
    try "rust components" run "${HOME}/.cargo/bin/rustup" component add clippy rustfmt rust-analyzer
  fi
}

module_defaults() {
  local script="${SCRIPT_DIR}/macos/defaults.sh"
  [[ -f "$script" ]] || {
    warn "missing ${script}"
    return 0
  }
  if confirm "Apply the macOS system defaults in macos/defaults.sh?"; then
    run bash "$script"
  else
    skip "macOS defaults"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"

  is_macos || die "This script targets macOS. On Linux run ./setup-linux-workstation.sh"

  info "macOS $(sw_vers -productVersion) on $(uname -m)"
  [[ "$DRY_RUN" == "true" ]] && warn "dry run — no changes will be made"

  require_sudo

  local module ran=() failed=()
  for module in "${MODULES[@]}"; do
    if selected "$module"; then
      header "${module} — $(module_desc "$module")"
      if "module_${module}"; then
        ran+=("$module")
      else
        failed+=("$module")
        warn "module ${module} did not complete cleanly"
      fi
    fi
  done

  header "Done"
  # ${ran[*]:-} rather than ${ran[*]}: on bash 3.2 expanding an empty array
  # under `set -u` is itself an "unbound variable" error, which would turn a
  # mistyped --only into a crash instead of an empty summary line.
  success "Modules completed: ${ran[*]:-}"
  [[ ${#failed[@]} -gt 0 ]] && warn "Modules with errors: ${failed[*]}"
  cat <<EOF

Next steps:
  1. ./install.sh                  link the dotfiles into \$HOME
  2. exec zsh                      start the new shell
  3. colima start                  start the container runtime (if not running)
EOF
}

main "$@"
