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
   brew install gh bitwarden
   gh auth login
   gh repo clone mtn-man/dotfiles ~/dev/dotfiles
   ```

3. Run the bootstrap script:

   ```bash
   cd ~/dev/dotfiles
   ./bootstrap.sh
   ```

   This installs packages from the Brewfile, sets Fish as the default shell, stows all dotfiles, fixes the Homebrew path override, suppresses the login message, and applies macOS defaults (window drag, Dock autohide, key repeat).

4. Install private Go tools (not in Brewfile):

   ```bash
   gh repo clone mtn-man/mintmedia ~/dev/mintmedia
   cd ~/dev/mintmedia && go install ./...
   ```

5. App setup — sign into Bitwarden, Tailscale, Spotify, etc. Grant Accessibility permissions for Hammerspoon and LinearMouse.

### Transmission

`~/dev/transmission/settings.json` is symlinked to `/opt/homebrew/var/transmission/settings.json` (not version controlled).

`bind-address-ipv4` is set to `10.5.0.2`, the NordVPN tunnel interface. This acts as a killswitch: if the VPN goes down, the daemon loses its bind address and peer connections stop — no traffic leaks over the default interface.

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
defaults write com.apple.dock autohide-delay -float 0
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
