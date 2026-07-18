# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for macOS (primary), a CentOS Stream 10 homelab (`server/`), and a Fedora Sway workstation (`fedora/`). Deployed via GNU Stow.

## Deployment

```fish
# Deploy a single package (from repo root)
stow -vt $HOME fish

# Deploy all packages
stow -vt $HOME */
```

Each package follows XDG convention: `<package>/.config/<package>/` → `~/.config/<package>/`.

- `server/` Fish config is sourced manually on the homelab (not stow-deployed).
- `fedora/` has its own bootstrap and stows `fish`, `lf`, `micro`, `kitty`, `sway`, `swaylock`, `waybar`, `rofi`, `yt-dlp`, `fastfetch`, and `git` (Sway desktop stack, with Linux-specific paths).

## Package Installation

```fish
brew bundle install   # macOS: install all tools from Brewfile
```

For Fedora, run `fedora/fedora-bootstrap` (installs via dnf + RPM Fusion, enables Tailscale, stows the Fedora-subset packages).

## Bootstrap

`bootstrap` bootstraps a new macOS machine: installs Brewfile packages, initializes the Rust toolchain, sets Fish as default shell, stows all dotfile packages, loads launchd agents, suppresses the login message, sets default apps, and applies macOS defaults (dock autohide, key repeat, window drag).

## Packages

- **`fish/`** — Shell config: `config.fish` (env vars, PATH), `abbrs.fish`, `functions/`, `completions/` (tm, writeiso)
- **`ghostty/`** — Terminal emulator config
- **`vim/`** — Primary terminal editor (`~/.vimrc`)
- **`micro/`** — Editor (Solarized theme, Go tool keybindings in `bindings.json`); being phased out in favor of vim
- **`git/`** — Git config (`~/.gitconfig`)
- **`kitty/`** — Terminal emulator config (kitty.conf + theme)
- **`lazygit/`** — Lazygit config
- **`lf/`** — File manager: fish-compatible zoxide integration via custom `z`/`cd` commands in `lfrc`, `pv.sh`/`clean.sh` for preview/cleanup, `e` bound to vim
- **`hammerspoon/`** — macOS automation: auto-launches/quits LinearMouse on Logitech USB receiver plug/unplug
- **`linearmouse/`** — Mouse config (managed by Hammerspoon automation)
- **`btop/`** — Resource monitor config
- **`mintmedia/`** — Config for the `mintmedia` Go tool; the ingest pipeline runs on the homelab, watching `/mnt/storage/Downloads/complete` for completed Transmission downloads
- **`fastfetch/`** — System info display config
- **`homebrew/`** — Tracks `~/.homebrew/trust.json` (trusted taps/formulae/casks) in version control
- **`launchd/`** — macOS launchd agents: `local.doctor.plist` runs `doctor-notify` daily at 9am
- **`raycast-scripts/`** — Raycast script commands
- **`server/`** — CentOS homelab: Fish config + `server.backup.sh` (rsync cold backup script)
- **`fedora/`** — Fedora Sway workstation: bootstrap script + fish/lf/micro/kitty/git configs, Sway compositor, swaylock, waybar, rofi, yt-dlp, fastfetch

## Network Architecture

**macOS:** Tailscale is always on and is the sole networking requirement for homelab access.

**Homelab torrenting stack** (Podman + systemd, CentOS Stream 10):

A two-container Podman stack runs as root and is managed by systemd:

- `nordvpn` container: owns the network namespace, establishes a NordLynx/WireGuard tunnel. All traffic in the namespace exits through `10.5.0.2` (the NordLynx interface). Kill switch enabled in NordVPN — if the tunnel drops, traffic stops. Authentication uses a NordVPN access token stored as a Podman secret (`nordvpn_token`).
- `transmission` container: shares the nordvpn network namespace (`--network container:nordvpn`), so all torrent peer traffic is bound to the VPN tunnel. RPC is published exclusively to `100.106.45.25:9091` (Tailscale interface). RPC authentication is disabled — Tailscale enforces access control.

Two subnets are allowlisted in NordVPN to bypass VPN routing: `10.88.0.0/16` (Podman bridge) and `100.64.0.0/10` (Tailscale CGNAT range), so the RPC port remains reachable over Tailscale.

`transmission.service` polls `nordvpn status` for up to 2 minutes waiting for `Status: Connected` before starting, and stops if nordvpn stops (`PartOf=nordvpn.service`). Both services start on boot and handle unclean shutdowns via pre-start container cleanup.

`tm.fish` on the Mac sends magnet links and torrents to the homelab at `$HOMELAB:9091` via `transmission-remote`.

## Key Fish Functions

| Function | Purpose |
|----------|---------|
| `doctor.fish` | System health check: toolchain, Tailscale connectivity, macOS security flags; exits 0=ok, 1=warn, 2=crit |
| `doctor-notify.fish` | Runs `doctor` and fires a native macOS Notification Center alert on warnings or criticals; called by launchd |
| `snap.fish` | Rebuild `~/dev/snapshot.md` with live system data (censors IPs and credentials) |
| `tm.fish` | Send magnet links and torrents to homelab Transmission via `transmission-remote` |
| `writeiso.fish` | Write ISO to USB: fzf disk picker, safety checks, `dd` with progress |
| `yt.fish` | YouTube download via yt-dlp |
| `fv.fish` | File search + edit in vim (fd + fzf), supports leading vim flags (e.g. `fv -y`, `fv +42`) |
| `fish_prompt.fish` | Custom prompt with git status indicators |
| `fish_right_prompt.fish` | Elapsed time for commands over threshold |
| `fish_greeting.fish` | Welcome message + fastfetch, once per terminal window |
| `lf.fish` | Wraps lf with quit-and-cd integration |
| `stow-add.fish` | Move a `~/.config` package into dotfiles and stow it |
| `stow-remove.fish` | Unstow a package and move it back to `~/.config` |
| `lp.fish` | List PATH entries with existence check |
| `__abbr_timer_minutes.fish` | Helper expanding `a15` → `after 15m` |

## Git Workflow

Never create commits unless explicitly instructed to. The user reviews all changes before committing.

## Git-ignored Paths

Fish shell state (`fish_history`, `fish_variables`, `conf.d/`), micro editor buffers/history, and `.DS_Store` files are excluded from version control.
