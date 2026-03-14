## Personal dotfiles repo

**Notes:**
- Stow: `stow -vt $HOME <package>` from repo root
- `server/` = CentOS Stream 10 homelab; everything else = macOS

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

**Max key repeat speed** (lf/fish/micro navigation):
```bash
defaults write -g InitialKeyRepeat -int 8
defaults write -g KeyRepeat -int 2
# Log out to apply
```
