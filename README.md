## Personal dotfiles repo

**Notes:**
- Stow: `stow -vt $HOME <package>` from repo root
- `server/` = CentOS Stream 10 homelab; everything else = macOS

### Fresh Mac Setup

1. Install [Homebrew](https://brew.sh) (also installs Xcode CLT):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Authenticate with GitHub and clone:
   ```bash
   brew install gh
   gh auth login
   gh repo clone mtn-man/dotfiles ~/dev/dotfiles
   ```

3. Install all packages:
   ```bash
   cd ~/dev/dotfiles
   brew bundle install
   ```

4. Set Fish as default shell:
   ```bash
   echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
   chsh -s /opt/homebrew/bin/fish
   ```

5. Stow all dotfiles:
   ```fish
   cd ~/dev/dotfiles
   stow -vt $HOME fish ghostty kitty micro lf fastfetch btop hammerspoon linearmouse mintmedia
   ```

6. App setup — sign into Bitwarden, Tailscale, Spotify, etc. Grant Accessibility permissions for Hammerspoon and LinearMouse.

### macOS Window + Dock

**Drag windows anywhere** (Cmd+Ctrl+click):
```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
```
Undo:
```bash
defaults delete -g NSWindowShouldDragOnGesture
```

**Fast Dock autohide (0s delay, 0.5x animation):**
```bash
defaults write com.apple.Dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.5
killall Dock
```
### Keyboard (CLI Speed)

**Fast, precise key repeat (lf/fish/micro navigation, beyond UI slider):**
```bash
defaults write -g InitialKeyRepeat -int 10
defaults write -g KeyRepeat -int 2
# Log out to apply
```
Undo:
```bash
defaults delete -g InitialKeyRepeat
defaults delete -g KeyRepeat
# Log out and back in to apply
```
