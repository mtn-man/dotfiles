# Fedora Sway Dotfiles

Notes on the Fedora Sway spin that aren't obvious from the code.

## System Services (provided by Fedora Sway spin, not configured in dotfiles)

- **Notification daemon:** `dunst` — use `dunstctl set-paused toggle` for DND, `dunstctl is-paused` to check state
- **Idle/lock:** `swayidle` — auto-lock and screen-off handled via `/usr/share/sway/config.d/`
- **Media/brightness keys:** bound via `/usr/share/sway/config.d/`
