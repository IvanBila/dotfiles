# shellcheck shell=bash
#
# Shared helpers for the dotfiles installer and the workstation setup scripts.
# Source this file; do not execute it.

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
else
  C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD='' C_DIM=''
fi

info() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
success() { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
error() { printf '%serr %s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
skip() { printf '%sskip%s %s\n' "$C_DIM" "$C_RESET" "$*"; }

die() {
  error "$*"
  exit 1
}

header() {
  printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"
  printf '%s%s%s\n' "$C_DIM" "$(printf '%.0s-' $(seq 1 ${#1}))" "$C_RESET"
}

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------

has() { command -v "$1" >/dev/null 2>&1; }

# $USER is not exported in every environment (containers, cron, CI).
CURRENT_USER="${USER:-$(id -un)}"
export CURRENT_USER

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }

is_debian_like() {
  is_linux && has apt-get
}

is_arm64() {
  [[ "$(uname -m)" == "arm64" || "$(uname -m)" == "aarch64" ]]
}

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

# os_release_field ID / VERSION_CODENAME / ...
os_release_field() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  (. /etc/os-release && printf '%s' "${!1:-}")
}

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

DRY_RUN="${DRY_RUN:-false}"

# run <cmd...> — echoes the command in dry-run mode, otherwise executes it.
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%s  would run:%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

# run_sh <shell string> — same as run(), for pipelines and redirection.
run_sh() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%s  would run:%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  bash -c "$*"
}

# try <description> <run|run_sh> <cmd...> — never aborts the script; a failure
# is a warning. Used for optional, network-dependent or third-party steps so one
# flaky download does not take the whole setup down with it.
try() {
  local what="$1"
  shift
  if "$@"; then
    return 0
  fi
  warn "$what failed; continuing"
  return 0
}

# retry <attempts> <cmd...> — exponential backoff between attempts.
retry() {
  local attempts="$1" delay=2 n=1
  shift
  until "$@"; do
    if ((n >= attempts)); then
      return 1
    fi
    warn "attempt $n/$attempts failed: $* (retrying in ${delay}s)"
    sleep "$delay"
    delay=$((delay * 2))
    n=$((n + 1))
  done
}

confirm() {
  local prompt="${1:-Continue?}"
  if [[ "${ASSUME_YES:-false}" == "true" ]]; then
    return 0
  fi
  local reply
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Ask once, up front, so the run is not interrupted by a password prompt
# in the middle of an unattended install.
require_sudo() {
  [[ "$DRY_RUN" == "true" ]] && return 0
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi
  has sudo || die "sudo is required but not installed"
  if ! sudo -n true 2>/dev/null; then
    info "Requesting sudo access (needed to install system packages)"
    sudo -v || die "sudo authentication failed"
  fi
  # Keep the sudo timestamp alive for the duration of the script.
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
  done 2>/dev/null &
}

# ---------------------------------------------------------------------------
# Module selection (shared by both workstation scripts)
# ---------------------------------------------------------------------------

# selected <module> — honours ONLY_MODULES / SKIP_MODULES (comma separated).
selected() {
  local module="$1"
  if [[ -n "${ONLY_MODULES:-}" ]]; then
    [[ ",${ONLY_MODULES}," == *",${module},"* ]] || return 1
  fi
  if [[ -n "${SKIP_MODULES:-}" ]]; then
    [[ ",${SKIP_MODULES}," == *",${module},"* ]] && return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Downloads
# ---------------------------------------------------------------------------

# fetch <url> — print a URL's contents to stdout, failing loudly on HTTP errors.
fetch() {
  curl --fail --silent --show-error --location --retry 3 --retry-delay 2 "$1"
}

# github_latest_asset <owner/repo> <grep pattern> — resolve a release asset URL.
github_latest_asset() {
  local repo="$1" pattern="$2"
  fetch "https://api.github.com/repos/${repo}/releases/latest" |
    grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' |
    sed -E 's/.*"(https[^"]+)"/\1/' |
    grep -E "$pattern" |
    head -n 1
}
