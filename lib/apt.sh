# shellcheck shell=bash
#
# apt/dpkg helpers for the Linux workstation script.
# Source lib/common.sh before this file.

APT_UPDATED=false
KEYRING_DIR=/etc/apt/keyrings

apt_update() {
  if [[ "$APT_UPDATED" == "true" ]]; then
    return 0
  fi
  info "Updating package lists"
  run sudo apt-get update -qq
  APT_UPDATED=true
}

apt_mark_stale() { APT_UPDATED=false; }

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "^install ok installed$"
}

# apt_install <packages...> — installs only what is missing, so re-runs are cheap.
apt_install() {
  local missing=()
  local pkg
  for pkg in "$@"; do
    pkg_installed "$pkg" || missing+=("$pkg")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    skip "already installed: $*"
    return 0
  fi
  apt_update
  info "Installing: ${missing[*]}"
  # Individually, so one unavailable package on an older release does not
  # take the rest of the group down with it.
  local failed=()
  for pkg in "${missing[@]}"; do
    run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" || failed+=("$pkg")
  done
  if [[ ${#failed[@]} -gt 0 ]]; then
    warn "could not install: ${failed[*]}"
  fi
}

# add_apt_repo <name> <key url> <repo line>
#
# Uses signed-by keyrings under /etc/apt/keyrings; apt-key has been deprecated
# since Ubuntu 20.10 and removed in 24.04.
add_apt_repo() {
  local name="$1" key_url="$2" repo_line="$3"
  local keyring="${KEYRING_DIR}/${name}.gpg"
  local list="/etc/apt/sources.list.d/${name}.list"

  run sudo install -m 0755 -d "$KEYRING_DIR"

  if [[ ! -s "$keyring" ]]; then
    info "Adding signing key for ${name}"
    run_sh "curl -fsSL --retry 3 '${key_url}' | sudo gpg --dearmor --yes -o '${keyring}'" ||
      {
        warn "failed to fetch ${name} signing key; skipping repository"
        return 1
      }
    run sudo chmod a+r "$keyring"
  fi

  if [[ ! -f "$list" ]] || ! grep -qF "$repo_line" "$list" 2>/dev/null; then
    info "Adding apt repository ${name}"
    run_sh "echo '${repo_line}' | sudo tee '${list}' >/dev/null"
    apt_mark_stale
  fi
}

deb_arch() { dpkg --print-architecture; }

# Ubuntu codename, falling back to the Debian one. Repos that only publish for
# Ubuntu need UBUNTU_CODENAME; on Debian we fall back to a recent LTS.
ubuntu_codename() {
  local codename
  codename="$(os_release_field UBUNTU_CODENAME)"
  [[ -z "$codename" ]] && codename="$(os_release_field VERSION_CODENAME)"
  printf '%s' "${codename:-jammy}"
}

# install_deb_from_github <owner/repo> <asset grep pattern> <command to test>
install_deb_from_github() {
  local repo="$1" pattern="$2" test_cmd="$3"
  if has "$test_cmd"; then
    skip "${test_cmd} already installed"
    return 0
  fi
  local url tmp
  url="$(github_latest_asset "$repo" "$pattern" || true)"
  if [[ -z "$url" ]]; then
    warn "no matching release asset for ${repo} (${pattern})"
    return 0
  fi
  tmp="$(mktemp -d)"
  info "Installing ${test_cmd} from ${repo}"
  if run_sh "curl -fsSL --retry 3 -o '${tmp}/pkg.deb' '${url}'"; then
    run sudo apt-get install -y -qq "${tmp}/pkg.deb" || warn "dpkg install of ${test_cmd} failed"
  else
    warn "download of ${test_cmd} failed"
  fi
  rm -rf "$tmp"
}

# install_raw_binary <url> <destination command name>
install_raw_binary() {
  local url="$1" name="$2"
  if [[ -z "$url" ]]; then
    warn "no download URL resolved for ${name}"
    return 0
  fi
  if has "$name"; then
    skip "${name} already installed"
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  info "Installing ${name}"
  if run_sh "curl -fsSL --retry 3 -o '${tmp}/${name}' '${url}'"; then
    run sudo install -m 0755 "${tmp}/${name}" "/usr/local/bin/${name}" ||
      warn "install of ${name} failed"
  else
    warn "download of ${name} failed"
  fi
  rm -rf "$tmp"
}

# install_tarball_binary <url> <path inside archive> <destination command name>
install_tarball_binary() {
  local url="$1" inner="$2" name="$3"
  if [[ -z "$url" ]]; then
    warn "no download URL resolved for ${name}"
    return 0
  fi
  if has "$name"; then
    skip "${name} already installed"
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  info "Installing ${name}"
  if run_sh "curl -fsSL --retry 3 -o '${tmp}/archive.tar.gz' '${url}'" &&
    run_sh "tar -xzf '${tmp}/archive.tar.gz' -C '${tmp}'"; then
    run sudo install -m 0755 "${tmp}/${inner}" "/usr/local/bin/${name}" ||
      warn "install of ${name} failed"
  else
    warn "download of ${name} failed"
  fi
  rm -rf "$tmp"
}
