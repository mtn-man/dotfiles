## Personal dotfiles repo

### Notes

* `stow -vt $HOME <package>` from repo root
* `server/` = CentOS Stream 10 homelab
* `fedora/` = Fedora development/testing machine
* Everything else targets macOS unless otherwise noted

### Fresh Mac Setup

1. Install Homebrew (also installs Xcode CLT):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Authenticate with GitHub and clone:

```bash
brew install gh bitwarden
gh auth login
gh repo clone mtn-man/dotfiles ~/dev/dotfiles
```

3. Run bootstrap:

```bash
cd ~/dev/dotfiles
./bootstrap.sh
```

This will:

* Install Brewfile packages
* Set Fish as the login shell
* Stow all managed configuration
* Apply macOS defaults
* Suppress the login banner

4. Install private Go tools:

```bash
gh repo clone mtn-man/mintmedia ~/dev/mintmedia
cd ~/dev/mintmedia && go install ./...
```

5. Sign into required services:

* Apple ID
* Bitwarden
* Tailscale
* GitHub
* NordVPN
* Spotify

### Manual Applications

App Store:

* Hush
* uBlock Origin Lite

Third-party:

* MakeMKV — https://www.makemkv.com/
* Supercharge — purchased via Gumroad

### Post-Recovery Checklist

Verify:

* `doctor` reports expected status
* Tailscale is connected
* Time Machine is configured
* Media share mounts successfully (`media on`)
* Raycast hotkeys work
* Hammerspoon loads successfully
* AeroSpace starts correctly

Accessibility permissions are required for:

* AeroSpace
* Ghostty
* Hammerspoon
* LinearMouse
* Raycast

Notes:

* Log out and back in after bootstrap so Fish becomes the login shell.
* `lf` image previews require Kitty (`kitten icat`), even though Ghostty is the primary terminal.
* Daily backups are performed via Time Machine.
* Dotfiles are backed up through GitHub.

````

### macOS Window + Dock

Drag windows anywhere:

```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
````

Undo:

```bash
defaults delete -g NSWindowShouldDragOnGesture
```

Fast Dock autohide:

```bash
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.5
killall Dock
```

### Keyboard

Fast key repeat:

```bash
defaults write -g InitialKeyRepeat -int 10
defaults write -g KeyRepeat -int 2
```

Undo:

```bash
defaults delete -g InitialKeyRepeat
defaults delete -g KeyRepeat
```
