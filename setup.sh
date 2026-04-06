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
chsh -s /opt/homebrew/bin/fish

echo "==> Stowing dotfiles..."
stow -vt "$HOME" fish ghostty kitty micro lf fastfetch btop hammerspoon linearmouse mintmedia

echo "==> Removing Homebrew path override from /etc/paths.d/..."
sudo rm -f /etc/paths.d/homebrew

echo "==> Suppressing login message..."
touch ~/.hushlogin

echo "==> Applying macOS defaults..."
defaults write -g NSWindowShouldDragOnGesture -bool true
defaults write com.apple.Dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.5
killall Dock

echo ""
echo "Done. Log out and back in for the Fish shell to take effect."
