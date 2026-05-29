# Fedora Sway Dotfiles

Notes on the Fedora Sway spin that aren't obvious from the code.

## System Services (provided by Fedora Sway spin, not configured in dotfiles)

- **Notification daemon:** `dunst` — use `dunstctl set-paused toggle` for DND, `dunstctl is-paused` to check state
- **Idle/lock:** `swayidle` — `config.d/90-swayidle.conf` powers displays off after 5 min; no auto-lock. Lock is triggered explicitly via the power menu (`$mod+Shift+Escape`) which calls `swaylock -f`
- **Media/brightness keys:** bound via `/usr/share/sway/config.d/`

## Packages

Deployed via GNU Stow from the `fedora/` subdirectory: `fish`, `lf`, `micro`, `kitty`, `sway`, `swaylock`, `waybar`, `rofi`, `yt-dlp`, `fastfetch`.

Out-of-repo packages are handled by bootstrap section 3 via COPR / external repos:
- **lf** — `lsevcik/lf` COPR
- **FiraCode Nerd Font** — `atim/nerd-fonts` COPR
- **Brave browser** — `brave-browser-beta.repo`
- **Tailscale** — `pkgs.tailscale.com/stable/fedora/tailscale.repo`
- **throttled** — `abn/throttled` COPR

## Theme

All layers share a consistent **Dark Pastel** palette:

| Role | Color |
|------|-------|
| Background | `#1C1C1C` |
| Foreground | `#DEDEDE` |
| Blue (normal/focused) | `#96CBFE` |
| Green (charging/active/safe) | `#A8FF60` |
| Yellow (warning/mode) | `#FFFFB6` |
| Red (critical/error) | `#FF6C60` |
| Cyan / Magenta | `#C6C5FE` / `#FF73FE` |

The wallpaper (`~/Pictures/artemisii-eclipse.jpeg`) is shared between Sway and Swaylock.

## Waybar

- **Signal 8** — the dunst DND custom module uses `signal: 8` to refresh; `$mod+Shift+n` in sway sends `pkill -SIGRTMIN+8 waybar` after toggling dunst
- **cpu module** — click opens btop in kitty
- **battery module** — click opens the `batt` fish function in kitty
- **custom/power** — click runs `~/.config/sway/power-menu.sh` (rofi dmenu: Shutdown / Restart / Sleep / Logout / Lock)

## Sway Config

- `config.d/` layering: system defaults in `/usr/share/sway/config.d/`, system overrides in `/etc/sway/config.d/`, user overrides in `~/.config/sway/config.d/`
- Workspace outputs prefer `DP-2` over `eDP-1` (external display when docked)
- Lid close/open events toggle the internal display (`eDP-1`) via `swaymsg output`
- Touchpad: Synaptics, natural scroll, tap-to-click, accel 0.3
- Mouse: Logitech G305, accel -0.5

## Fish Shell

Stripped-down compared to macOS — no VPN, media, doctor, or snap functions. Fedora-specific functions:

| Function | Purpose |
|----------|---------|
| `batt` | Shows upower battery details (excludes history) |
| `update` | Runs `dnf upgrade --refresh` |
| `yt` | yt-dlp wrapper: reads URL from clipboard if omitted, interactive codec/res picker (`-i`), downloads to `~/Videos/YouTube`, embeds metadata & thumbnails, maintains archive |
| `gr` | Jump to git repo under `~/dev` via fzf, auto-runs `eza -aTL4` on arrival |
| `fm` | Find file by name: searches `~/dev` first, falls back to cwd, fzf picker with bat preview |
| `gcp` | Stage all, confirm, commit (message or editor), push |
| `lf` | Wraps lf with quit-and-cd integration, evicts old thumbnails (30d+) and stale tmp files (1d+) |
| `stow-add` | Moves `~/.config/<pkg>` into dotfiles and stows it |
| `tm` | Send magnet links and torrents to homelab Transmission via `transmission-remote` (shared with macOS) |

## lf Preview (`pv.sh`)

- Dependency cache keyed against the RPM DB (`rpm -qa` hash) — preview scripts rebuild automatically when packages change
- Video files: extracts embedded thumbnail via ffmpeg (copies mjpeg/webp/png stream, no transcode)
- Images: rendered via `kitten icat` (Kitty terminal graphics protocol)
- Text: rendered via `bat` with syntax highlighting
- Thumbnail cache: MD5-keyed by file path + mtime, stored in `~/.cache/lf/thumbs/`

## Fish Prompt

- Git status caches for **3 seconds per directory**, invalidating on `.git/HEAD` change (catches branch switches and resets without stat-ing on every keystroke)
- Right prompt shows command duration only when > 3 seconds
