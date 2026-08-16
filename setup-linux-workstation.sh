#!/usr/bin/env bash
#
# Provision a Debian/Ubuntu development workstation.
#
# Every module is idempotent: re-running the script installs what is missing
# and leaves everything else alone.
#
#   ./setup-linux-workstation.sh                  # everything
#   ./setup-linux-workstation.sh --only docker,node
#   ./setup-linux-workstation.sh --skip apps,php --yes
#   ./setup-linux-workstation.sh --dry-run        # print, do not touch the system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/apt.sh
source "${SCRIPT_DIR}/lib/apt.sh"
# shellcheck source=lib/shell.sh
source "${SCRIPT_DIR}/lib/shell.sh"

MODULES=(
  core cli shell docker node python go rust java php ruby
  db k8s cloud editors apps fonts
)

PHP_VERSION="${PHP_VERSION:-8.3}"

declare -A MODULE_DESC=(
  [core]="Build toolchain, compression, networking and library headers"
  [cli]="Modern terminal tooling (ripgrep, fzf, bat, delta, gh, lazygit, ...)"
  [shell]="zsh, oh-my-zsh, spaceship prompt, autosuggestions, syntax highlighting"
  [docker]="Docker Engine, Buildx, Compose v2, lazydocker, dive, ctop"
  [node]="nvm, Node.js LTS, corepack (yarn/pnpm) and global CLIs"
  [python]="python3 toolchain, pipx, uv, poetry, ruff, pre-commit"
  [go]="Latest stable Go toolchain into /usr/local/go"
  [rust]="rustup, cargo, clippy, rustfmt"
  [java]="SDKMAN with the current Java LTS, Maven and Gradle"
  [php]="PHP ${PHP_VERSION} with common extensions, Composer, Laravel installer"
  [ruby]="rbenv and ruby-build"
  [db]="Database clients (psql, mariadb, redis, sqlite, pgcli, mycli)"
  [k8s]="kubectl, helm, k9s, kind, kubectx/kubens"
  [cloud]="AWS, gcloud, Terraform, Ansible and the deploy CLIs (supabase, firebase, vercel, heroku, eas)"
  [editors]="Visual Studio Code"
  [apps]="GUI apps: browsers, Slack, Discord, Postman, Signal, VLC"
  [fonts]="JetBrains Mono / FiraCode Nerd Fonts and powerline fonts"
)

HEADLESS="${HEADLESS:-false}"
ONLY_MODULES="" SKIP_MODULES="" ASSUME_YES=false

usage() {
  cat <<EOF
${C_BOLD}setup-linux-workstation.sh${C_RESET} — provision a Debian/Ubuntu dev machine

Usage: $(basename "$0") [options]

Options:
  --only  <a,b,c>   Run only these modules
  --skip  <a,b,c>   Run everything except these modules
  --list            List available modules and exit
  --php-version <v> PHP version to install (default: ${PHP_VERSION})
  --headless        Skip GUI applications, fonts and editors
  --dry-run         Print what would happen without changing anything
  -y, --yes         Assume yes for all prompts
  -h, --help        Show this help

Modules run in dependency order: ${MODULES[*]}
EOF
}

list_modules() {
  printf '%sAvailable modules%s\n' "$C_BOLD" "$C_RESET"
  local m
  for m in "${MODULES[@]}"; do
    printf '  %-9s %s\n' "$m" "${MODULE_DESC[$m]}"
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only)
        ONLY_MODULES="${2:?--only needs a value}"
        shift 2
        ;;
      --skip)
        SKIP_MODULES="${2:?--skip needs a value}"
        shift 2
        ;;
      --php-version)
        PHP_VERSION="${2:?--php-version needs a value}"
        shift 2
        ;;
      --list)
        list_modules
        exit 0
        ;;
      --headless)
        HEADLESS=true
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
  if [[ "$HEADLESS" == "true" ]]; then
    SKIP_MODULES="${SKIP_MODULES:+${SKIP_MODULES},}apps,fonts,editors"
  fi
}

# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------

module_core() {
  apt_install \
    build-essential ca-certificates curl wget file gnupg openssl \
    apt-transport-https software-properties-common pkg-config \
    git git-lfs \
    make cmake automake autoconf libtool \
    unzip zip xz-utils p7zip-full \
    net-tools dnsutils iputils-ping traceroute openssh-client rsync \
    xclip xsel \
    zlib1g-dev libssl-dev libffi-dev libreadline-dev libsqlite3-dev \
    libbz2-dev libncurses-dev libgdbm-dev liblzma-dev tk-dev

  if has git-lfs; then
    try "git-lfs setup" run git lfs install --skip-repo
  fi
}

module_cli() {
  apt_install \
    zsh tmux vim neovim \
    htop btop tree ncdu jq \
    ripgrep fd-find bat fzf silversearcher-ag \
    shellcheck shfmt direnv tldr neofetch \
    zoxide eza just hyperfine

  # Ubuntu ships fd as fdfind and bat as batcat to avoid name clashes.
  run mkdir -p "${HOME}/.local/bin"
  if has fdfind && ! has fd; then
    run ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"
  fi
  if has batcat && ! has bat; then
    run ln -sf "$(command -v batcat)" "${HOME}/.local/bin/bat"
  fi

  # GitHub CLI
  add_apt_repo github-cli \
    "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
    "deb [arch=$(deb_arch) signed-by=${KEYRING_DIR}/github-cli.gpg] https://cli.github.com/packages stable main" &&
    apt_install gh

  # Tools that are absent or badly out of date in the Ubuntu archive.
  install_deb_from_github "dandavison/delta" "git-delta_.*_$(deb_arch)\.deb" delta
  install_deb_from_github "sharkdp/hyperfine" "hyperfine_.*_$(deb_arch)\.deb" hyperfine

  local arch_tag
  arch_tag="$([[ "$(deb_arch)" == "arm64" ]] && echo "arm64" || echo "x86_64")"
  install_tarball_binary \
    "$(github_latest_asset jesseduffield/lazygit "lazygit_.*_Linux_${arch_tag}\.tar\.gz" || true)" \
    lazygit lazygit
  install_raw_binary \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(deb_arch)" yq
}

module_shell() {
  apt_install zsh
  install_zsh_framework
  set_default_shell_zsh
}

module_docker() {
  if has docker && docker compose version >/dev/null 2>&1; then
    skip "docker engine and compose already installed"
  else
    local distro
    distro="$(os_release_field ID)"
    [[ "$distro" == "ubuntu" || "$distro" == "debian" ]] || distro="ubuntu"

    add_apt_repo docker \
      "https://download.docker.com/linux/${distro}/gpg" \
      "deb [arch=$(deb_arch) signed-by=${KEYRING_DIR}/docker.gpg] https://download.docker.com/linux/${distro} $(ubuntu_codename) stable"

    apt_install docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
  fi

  # Run docker without sudo. Requires a new login session to take effect.
  if ! id -nG "$CURRENT_USER" | tr ' ' '\n' | grep -qx docker; then
    info "Adding ${CURRENT_USER} to the docker group"
    run sudo groupadd -f docker
    run sudo usermod -aG docker "$CURRENT_USER"
    warn "log out and back in (or run 'newgrp docker') before using docker without sudo"
  fi

  if has systemctl && ! is_wsl; then
    try "enable docker service" run sudo systemctl enable --now docker
  fi

  # Container ergonomics.
  local arch_tag
  arch_tag="$([[ "$(deb_arch)" == "arm64" ]] && echo "arm64" || echo "x86_64")"
  install_tarball_binary \
    "$(github_latest_asset jesseduffield/lazydocker "lazydocker_.*_Linux_${arch_tag}\.tar\.gz" || true)" \
    lazydocker lazydocker
  install_deb_from_github "wagoodman/dive" "dive_.*_linux_$(deb_arch)\.deb" dive
  install_raw_binary \
    "https://github.com/bcicen/ctop/releases/latest/download/ctop-0.7.7-linux-$(deb_arch)" ctop
}

module_node() {
  local nvm_dir="${NVM_DIR:-${HOME}/.nvm}"
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
  if has corepack; then
    corepack enable
    corepack prepare yarn@stable pnpm@latest --activate
  fi
  # Deploy CLIs (vercel, firebase, heroku, eas) live in the cloud module.
  npm install -g npm@latest typescript ts-node tsx eslint prettier \
    serve nodemon npm-check-updates
  set -eu
}

module_python() {
  apt_install python3 python3-pip python3-venv python3-dev pipx

  if has pipx; then
    run pipx ensurepath >/dev/null 2>&1 || true
    local tool
    for tool in poetry ruff black mypy pre-commit httpie ipython virtualenv; do
      if pipx list --short 2>/dev/null | grep -q "^${tool} "; then
        skip "pipx ${tool} already installed"
      else
        try "pipx install ${tool}" run pipx install "$tool"
      fi
    done
  fi

  # uv: fast resolver/installer, also manages Python versions.
  if has uv; then
    skip "uv already installed"
  else
    try "uv install" run_sh "curl -LsSf https://astral.sh/uv/install.sh | sh"
  fi
}

module_go() {
  if has go && [[ -x /usr/local/go/bin/go ]]; then
    skip "go $(/usr/local/go/bin/go version | awk '{print $3}') already installed"
    return 0
  fi

  local version
  version="$(fetch 'https://go.dev/VERSION?m=text' 2>/dev/null | head -n 1 || true)"
  [[ "$version" == go* ]] || version="go1.23.5"

  local tmp
  tmp="$(mktemp -d)"
  info "Installing ${version}"
  if run_sh "curl -fsSL --retry 3 -o '${tmp}/go.tar.gz' 'https://go.dev/dl/${version}.linux-$(deb_arch).tar.gz'"; then
    run sudo rm -rf /usr/local/go
    run sudo tar -C /usr/local -xzf "${tmp}/go.tar.gz"
    success "go installed to /usr/local/go (PATH is set in ~/.exports)"
  else
    warn "go download failed"
  fi
  rm -rf "$tmp"
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

module_java() {
  apt_install zip unzip

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

module_php() {
  if is_debian_like && [[ "$(os_release_field ID)" == "ubuntu" ]]; then
    # The PPA lands as a .list or, on newer releases, a deb822 .sources file.
    if ! compgen -G "/etc/apt/sources.list.d/ondrej-ubuntu-php-*" >/dev/null; then
      info "Adding ondrej/php PPA"
      try "add ondrej/php" run sudo add-apt-repository -y ppa:ondrej/php
      apt_mark_stale
    fi
  else
    add_apt_repo php-sury \
      "https://packages.sury.org/php/apt.gpg" \
      "deb [signed-by=${KEYRING_DIR}/php-sury.gpg] https://packages.sury.org/php/ $(os_release_field VERSION_CODENAME) main" || true
  fi

  local v="$PHP_VERSION"
  apt_install \
    "php${v}" "php${v}-cli" "php${v}-common" "php${v}-curl" "php${v}-mbstring" \
    "php${v}-xml" "php${v}-zip" "php${v}-bcmath" "php${v}-gd" "php${v}-intl" \
    "php${v}-mysql" "php${v}-pgsql" "php${v}-sqlite3" "php${v}-soap" \
    "php${v}-opcache" "php${v}-redis" "php${v}-xdebug"

  # Composer, with the upstream installer signature check.
  if has composer; then
    skip "composer already installed"
  else
    info "Installing Composer"
    local tmp
    tmp="$(mktemp -d)"
    if run_sh "cd '${tmp}' && curl -fsSL -o composer-setup.php https://getcomposer.org/installer &&
        EXPECTED=\$(curl -fsSL https://composer.github.io/installer.sig) &&
        ACTUAL=\$(php -r \"echo hash_file('sha384', 'composer-setup.php');\") &&
        [ \"\$EXPECTED\" = \"\$ACTUAL\" ] &&
        sudo php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer"; then
      success "composer installed"
    else
      warn "composer installer signature mismatch or download failed"
    fi
    rm -rf "$tmp"
  fi

  if has composer; then
    try "laravel installer" run composer global require --no-interaction laravel/installer
    try "psysh" run composer global require --no-interaction psy/psysh:@stable
  fi
}

module_ruby() {
  if [[ -d "${HOME}/.rbenv" ]]; then
    skip "rbenv already installed"
  else
    info "Installing rbenv"
    try "rbenv clone" run git clone --depth 1 https://github.com/rbenv/rbenv.git "${HOME}/.rbenv"
  fi
  if [[ -d "${HOME}/.rbenv/plugins/ruby-build" ]]; then
    skip "ruby-build already installed"
  else
    run mkdir -p "${HOME}/.rbenv/plugins"
    try "ruby-build clone" run git clone --depth 1 \
      https://github.com/rbenv/ruby-build.git "${HOME}/.rbenv/plugins/ruby-build"
  fi
  info "Install a Ruby with: rbenv install -l && rbenv install <version>"
}

module_db() {
  # Clients only. Run the servers themselves as containers — see
  # 'docker compose' in a project repo rather than polluting the host.
  apt_install postgresql-client mariadb-client redis-tools sqlite3 pgcli mycli
}

module_k8s() {
  add_apt_repo kubernetes \
    "https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key" \
    "deb [signed-by=${KEYRING_DIR}/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" &&
    apt_install kubectl

  add_apt_repo helm \
    "https://baltocdn.com/helm/signing.asc" \
    "deb [arch=$(deb_arch) signed-by=${KEYRING_DIR}/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" &&
    apt_install helm

  install_deb_from_github "derailed/k9s" "k9s_linux_$(deb_arch)\.deb" k9s
  install_raw_binary \
    "https://kind.sigs.k8s.io/dl/latest/kind-linux-$(deb_arch)" kind
  apt_install kubectx
}

module_cloud() {
  if has aws; then
    skip "aws cli already installed"
  else
    local tmp arch
    arch="$(uname -m)"
    tmp="$(mktemp -d)"
    info "Installing AWS CLI v2"
    if run_sh "curl -fsSL --retry 3 -o '${tmp}/awscliv2.zip' 'https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip' &&
        unzip -q '${tmp}/awscliv2.zip' -d '${tmp}' && sudo '${tmp}/aws/install' --update"; then
      success "aws cli installed"
    else
      warn "aws cli install failed"
    fi
    rm -rf "$tmp"
  fi

  # Google Cloud CLI. The gke auth plugin is what kubectl needs to talk to GKE.
  add_apt_repo google-cloud \
    "https://packages.cloud.google.com/apt/doc/apt-key.gpg" \
    "deb [arch=$(deb_arch) signed-by=${KEYRING_DIR}/google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main" &&
    apt_install google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin

  add_apt_repo hashicorp \
    "https://apt.releases.hashicorp.com/gpg" \
    "deb [arch=$(deb_arch) signed-by=${KEYRING_DIR}/hashicorp.gpg] https://apt.releases.hashicorp.com $(ubuntu_codename) main" &&
    apt_install terraform

  apt_install ansible

  # Supabase publishes .deb packages; a global npm install is explicitly
  # unsupported upstream, so this one does not go through npm_global_install.
  install_deb_from_github "supabase/cli" "supabase_.*_linux_$(deb_arch)\.deb\$" supabase

  # The remaining platform CLIs only ship on npm. `expo-cli` is deprecated:
  # eas-cli covers builds and submissions, and projects run `npx expo` locally.
  npm_global_install vercel firebase-tools heroku eas-cli
}

module_editors() {
  add_apt_repo microsoft \
    "https://packages.microsoft.com/keys/microsoft.asc" \
    "deb [arch=$(deb_arch) signed-by=${KEYRING_DIR}/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" &&
    apt_install code || warn "Visual Studio Code repository unavailable"
}

module_apps() {
  # Google Chrome (no arm64 build published for Linux).
  if [[ "$(deb_arch)" == "amd64" ]]; then
    add_apt_repo google-chrome \
      "https://dl.google.com/linux/linux_signing_key.pub" \
      "deb [arch=amd64 signed-by=${KEYRING_DIR}/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" &&
      apt_install google-chrome-stable
  fi
  apt_install firefox

  # Signal
  if [[ "$(deb_arch)" == "amd64" ]]; then
    add_apt_repo signal \
      "https://updates.signal.org/desktop/apt/keys.asc" \
      "deb [arch=amd64 signed-by=${KEYRING_DIR}/signal.gpg] https://updates.signal.org/desktop/apt xenial main" &&
      apt_install signal-desktop
  fi

  if ! has snap; then
    warn "snapd not available; skipping snap applications"
    return 0
  fi

  local snap
  for snap in discord postman insomnia obsidian spotify vlc telegram-desktop; do
    if snap list "$snap" >/dev/null 2>&1; then
      skip "snap ${snap} already installed"
    else
      try "snap install ${snap}" run sudo snap install "$snap"
    fi
  done
  # Slack requires classic confinement.
  if snap list slack >/dev/null 2>&1; then
    skip "snap slack already installed"
  else
    try "snap install slack" run sudo snap install slack --classic
  fi
}

module_fonts() {
  apt_install fonts-powerline fonts-firacode fontconfig

  local font_dir="${HOME}/.local/share/fonts"
  run mkdir -p "$font_dir"

  local font
  for font in JetBrainsMono FiraCode Hack; do
    if compgen -G "${font_dir}/${font}*" >/dev/null; then
      skip "${font} Nerd Font already installed"
      continue
    fi
    local tmp
    tmp="$(mktemp -d)"
    info "Installing ${font} Nerd Font"
    if run_sh "curl -fsSL --retry 3 -o '${tmp}/${font}.zip' \
        'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip' &&
        unzip -qo '${tmp}/${font}.zip' -d '${font_dir}/${font}'"; then
      success "${font} Nerd Font installed"
    else
      warn "${font} Nerd Font download failed"
    fi
    rm -rf "$tmp"
  done

  try "font cache" run fc-cache -f
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"

  is_linux || die "This script targets Linux. On macOS run ./setup-macos-workstation.sh"
  is_debian_like || die "This script targets Debian/Ubuntu (apt) systems"

  info "Distribution: $(os_release_field PRETTY_NAME) ($(deb_arch))"
  is_wsl && info "WSL detected: systemd services and GUI apps may not apply"
  [[ "$DRY_RUN" == "true" ]] && warn "dry run — no changes will be made"

  require_sudo
  apt_update

  local module ran=() failed=()
  for module in "${MODULES[@]}"; do
    if selected "$module"; then
      header "${module} — ${MODULE_DESC[$module]}"
      if "module_${module}"; then
        ran+=("$module")
      else
        failed+=("$module")
        warn "module ${module} did not complete cleanly"
      fi
    fi
  done

  header "Done"
  success "Modules completed: ${ran[*]}"
  [[ ${#failed[@]} -gt 0 ]] && warn "Modules with errors: ${failed[*]}"
  cat <<EOF

Next steps:
  1. ./install.sh                  link the dotfiles into \$HOME
  2. log out and back in           picks up the docker group and login shell
  3. exec zsh                      start the new shell now
EOF
}

main "$@"
