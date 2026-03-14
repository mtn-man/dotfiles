## Personal dotfiles repo

Notes:
- Stow must be run from repo root. Use pattern `stow -vt $HOME <package>`
- Files in server/ are for my CentOS Stream 10 homelab - all other files target macOS

### Custom commands:

Move windows with  cmd + ctrl + click on any part of a window:
```bash
	defaults write -g NSWindowShouldDragOnGesture -bool true
```
and disable it
```bash
	defaults delete -g NSWindowShouldDragOnGesture
```

Sane dock autohide delay:
```bash
	defaults write com.apple.Dock autohide-delay -float 0
	defaults write com.apple.dock autohide-time-modifier -int 1
	killall Dock
```
