#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# Ensure Homebrew is on PATH for fresh shell sessions where brew shellenv
# hasn't been evaluated yet (e.g. opening a new terminal between steps).
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "==> Trusting third-party taps..."
brew trust mtn-man/tools
brew trust nikitabobko/tap
brew trust xykong/tap

echo "==> Installing packages from Brewfile..."
brew bundle install --file="$DOTFILES/Brewfile"

echo "==> Setting Fish as default shell..."
if ! grep -qF /opt/homebrew/bin/fish /etc/shells; then
    echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells > /dev/null
fi
# Note: chsh prompts for your login password (separate from sudo)
if [ "$SHELL" != /opt/homebrew/bin/fish ]; then
    chsh -s /opt/homebrew/bin/fish
fi

echo "==> Checking for stow conflicts..."
if ! stow -nRvt "$HOME" --dir="$DOTFILES" fish ghostty micro lf fastfetch btop hammerspoon linearmouse mintmedia; then
    echo "error: stow conflict detected — resolve the above before re-running." >&2
    exit 1
fi

echo "==> Stowing dotfiles..."
stow -Rvt "$HOME" --dir="$DOTFILES" fish ghostty micro lf fastfetch btop hammerspoon linearmouse mintmedia

echo "==> Suppressing login message..."
touch ~/.hushlogin

echo "==> Applying macOS defaults..."

# General UI
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Text input
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Keyboard
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write NSGlobalDomain InitialKeyRepeat -int 10
defaults write NSGlobalDomain KeyRepeat -int 2

# Trackpad
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Screen
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture type -string "jpg"
defaults write com.apple.screencapture disable-shadow -bool true

# Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
chflags nohidden ~/Library
xattr -d com.apple.FinderInfo ~/Library 2>/dev/null || true

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.dock tilesize -int 36
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock showhidden -bool true

# Photos
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Software Update
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

killall Dock   # always running; safe to restart
killall Finder # always running; safe to restart

echo "Done. Log out and back in for the Fish shell to take effect."
