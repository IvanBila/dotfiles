#!/usr/bin/env bash
#
# Opinionated macOS system defaults for a development machine.
# Run directly, or via ./setup-macos-workstation.sh --defaults.
#
# Everything here is reversible through System Settings; nothing is destructive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

is_macos || die "macos/defaults.sh only runs on macOS"

# Close System Settings so it does not overwrite what we change.
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1 || true

header "Keyboard & input"
# A fast key repeat is the single biggest quality-of-life win in a terminal.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Disable press-and-hold for accented characters so key repeat works in Vim.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Full keyboard access: tab through every control in dialogs.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
# Text substitutions that corrupt code snippets.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

header "Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" # list view
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf" # search current folder
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Keep folders on top when sorting by name.
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# Do not litter network shares and USB drives with .DS_Store files.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

header "Dock & Mission Control"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 44
defaults write com.apple.dock mru-spaces -bool false # do not reorder spaces
defaults write com.apple.dock expose-group-apps -bool true

header "Screenshots"
mkdir -p "${HOME}/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

header "Safari & security"
# Save to disk by default rather than iCloud.
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
# Require a password immediately after sleep or screen saver.
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
# Expand the save and print panels by default.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

header "Terminal & developer"
# UTF-8 only in Terminal.app.
defaults write com.apple.terminal StringEncodings -array 4
# Show battery percentage.
defaults write com.apple.menuextra.battery ShowPercent -bool true
# Faster window resize animations.
defaults write NSGlobalDomain NSWindowResizeTime -float 0.05

header "Restarting affected apps"
for app in Finder Dock SystemUIServer; do
  killall "$app" >/dev/null 2>&1 || true
done

success "macOS defaults applied. Some changes need a logout or restart."
