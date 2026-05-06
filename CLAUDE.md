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
- `fedora/` has its own bootstrap and stows `fish`, `lf`, `kitty`, `sway`, `swaylock`, and `waybar` (Sway desktop stack, with Linux-specific paths).

## Package Installation

```fish
brew bundle install   # macOS: install all tools from Brewfile
```

For Fedora, run `fedora/fedora-bootstrap.sh` (installs via dnf + RPM Fusion, enables Tailscale, stows the Fedora-subset packages).

## Bootstrap

`bootstrap.sh` bootstraps a new macOS machine: installs Brewfile packages, sets Fish as default shell, stows all dotfile packages, suppresses the login message, and applies macOS defaults (dock autohide, key repeat, window drag).

## Packages

- **`fish/`** — Shell config: `config.fish` (env vars, PATH), `abbrs.fish`, `functions/`, `completions/` (vpn, media, tm)
- **`ghostty/`** — Terminal emulator config
- **`micro/`** — Editor (Solarized theme, Go tool keybindings in `bindings.json`)
- **`lf/`** — File manager: fish-compatible zoxide integration via custom `z`/`cd` commands in `lfrc`, `pv.sh`/`clean.sh` for preview/cleanup, `e` bound to micro
- **`hammerspoon/`** — macOS automation: auto-launches/quits LinearMouse on Logitech USB receiver plug/unplug; runs `tailscale up` automatically when joining the home WiFi network
- **`linearmouse/`** — Mouse config (managed by Hammerspoon automation)
- **`btop/`** — Resource monitor config
- **`mintmedia/`** — Config for the `mintmedia` Go tool: watches `~/Downloads/MintDrop`, routes media files to `/Volumes/media/{Movies,Shows}` (the homelab SMB share), integrates with Transmission at `localhost:9091`
- **`fastfetch/`** — System info display config
- **`server/`** — CentOS homelab: Fish config + `server.backup.sh` (rsync cold backup script)
- **`fedora/`** — Fedora Sway workstation: bootstrap script + fish/lf/kitty configs, Sway compositor, swaylock, waybar

## Network Architecture (VPN Two-Mode Model)

The system enforces one of two mutually exclusive network modes via `vpn.fish`:

- **VPN mode** (`vpn on`): NordVPN connected via `scutil --nc`, Tailscale brought down. Used for general browsing.
- **Tailscale mode** (`vpn off`): Tailscale up, NordVPN disconnected. Required for homelab access.

`media on` calls `vpn off` first (entering Tailscale mode) before mounting the SMB share. `media off` calls `vpn on` after unmounting. The `vpn on` path also proactively unmounts the media share before switching — SMB over Tailscale won't survive the routing change. Hammerspoon reinforces this: joining the home WiFi automatically runs `tailscale up`.

`doctor` verifies the current mode (delegating to `vpn status`) and checks the Transmission `bind-address-ipv4` against the active VPN interface IP as a kill-switch audit (see below).

## Transmission VPN Kill Switch

`~/dev/transmission/settings.json` is symlinked to `/opt/homebrew/var/transmission/settings.json` (not version-controlled, not in repo). `bind-address-ipv4` is set to the NordVPN tunnel interface IP (`10.5.0.2`). If the VPN drops, the daemon loses its bind address and peer traffic stops — no leak through the default interface.

`doctor` audits this at runtime: when VPN is active it verifies the bind address matches the VPN interface IP; when VPN is inactive it checks the bind address is unreachable.

## Key Fish Functions

| Function | Purpose |
|----------|---------|
| `vpn.fish` | Enforce VPN/Tailscale two-mode model via `scutil --nc` and `tailscale` |
| `media.fish` | Homelab SMB mount with automatic network mode transitions |
| `doctor.fish` | System health check: toolchain, mount status, VPN mode, transmission kill-switch, macOS security flags |
| `snap.fish` | Rebuild `~/dev/snapshot.md` with live system data (censors IPs and credentials) |
| `tm.fish` | Transmission-CLI service management and magnet/torrent link handler |
| `writeiso.fish` | Write ISO to USB: fzf disk picker, safety checks, `dd` with progress |
| `update.fish` | Homebrew upgrade wrapper |
| `yt.fish` | YouTube download via yt-dlp |
| `fm.fish` | File search + edit (fd + fzf + micro) |
| `gr.fish` | Git repo discovery and navigation |
| `gcp.fish` | Stage all, commit (message or editor), and push |
| `fish_prompt.fish` | Custom prompt with git status indicators |
| `fish_right_prompt.fish` | Elapsed time for commands over threshold |
| `fish_greeting.fish` | Welcome message + fastfetch, once per terminal window |
| `lf.fish` | Wraps lf with quit-and-cd integration |
| `stow-add.fish` | Move a `~/.config` package into dotfiles and stow it |
| `caf.fish` | Prevent sleep for a duration |
| `mkcd.fish` | Create directory and cd into it |
| `lp.fish` | List PATH entries with existence check |
| `__abbr_timer_minutes.fish` | Helper expanding `a15` → `after 15m` |

## Git Workflow

Never create commits unless explicitly instructed to. The user reviews all changes before committing.

## Git-ignored Paths

Fish shell state (`fish_history`, `fish_variables`, `conf.d/`), micro editor buffers/history, and `.DS_Store` files are excluded from version control.
