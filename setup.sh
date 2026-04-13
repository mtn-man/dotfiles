#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing packages from Brewfile..."
brew bundle install --file="$DOTFILES/Brewfile"

echo "==> Setting Fish as default shell..."
if ! grep -qF /opt/homebrew/bin/fish /etc/shells; then
    echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
fi
# Note: chsh prompts for your login password (separate from sudo)
if [ "$SHELL" != /opt/homebrew/bin/fish ]; then
    chsh -s /opt/homebrew/bin/fish
fi

echo "==> Stowing dotfiles..."
stow -Rvt "$HOME" fish ghostty micro lf fastfetch btop hammerspoon linearmouse mintmedia

echo "==> Suppressing login message..."
touch ~/.hushlogin

echo "==> Applying macOS defaults..."
defaults write -g NSWindowShouldDragOnGesture -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.5
killall Dock # Dock is always running on macOS; this is safe
defaults write -g InitialKeyRepeat -int 10
defaults write -g KeyRepeat -int 2

echo ""
echo "Done. Log out and back in for the Fish shell to take effect."
