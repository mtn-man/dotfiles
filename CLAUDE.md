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

- **`fish/`** — Shell config: `config.fish` (env vars, PATH), `abbrs.fish`, `functions/`, `completions/` (media, tm)
- **`ghostty/`** — Terminal emulator config
- **`micro/`** — Editor (Solarized theme, Go tool keybindings in `bindings.json`)
- **`lf/`** — File manager: fish-compatible zoxide integration via custom `z`/`cd` commands in `lfrc`, `pv.sh`/`clean.sh` for preview/cleanup, `e` bound to micro
- **`hammerspoon/`** — macOS automation: auto-launches/quits LinearMouse on Logitech USB receiver plug/unplug; runs `tailscale up` automatically when joining the home WiFi network
- **`linearmouse/`** — Mouse config (managed by Hammerspoon automation)
- **`btop/`** — Resource monitor config
- **`mintmedia/`** — Config for the `mintmedia` Go tool; the ingest pipeline runs on the homelab, watching `/mnt/storage/Downloads/MintDrop` for completed Transmission downloads
- **`fastfetch/`** — System info display config
- **`server/`** — CentOS homelab: Fish config + `server.backup.sh` (rsync cold backup script)
- **`fedora/`** — Fedora Sway workstation: bootstrap script + fish/lf/kitty/micro configs, Sway compositor, swaylock, waybar

## Network Architecture

**macOS:** Tailscale is always on and is the sole networking requirement for homelab access. NordVPN is managed via the GUI and has no scripted integration. `vpn.fish` is deprecated — macOS changes made `scutil --nc` control unreliable, and the Mac-side Transmission kill switch it supported broke when NordVPN changed its tunnel interface IP after an update.

`media on` verifies Tailscale is running (`BackendState == Running`) before mounting the SMB share, and aborts with a clear error if not. `media on -l` skips this check (local network). Hammerspoon auto-runs `tailscale up` when joining the home WiFi network.

**Homelab torrenting stack** (Podman + systemd, CentOS Stream 10):

A two-container Podman stack runs as root and is managed by systemd:

- `nordvpn` container: owns the network namespace, establishes a NordLynx/WireGuard tunnel. All traffic in the namespace exits through `10.5.0.2` (the NordLynx interface). Kill switch enabled in NordVPN — if the tunnel drops, traffic stops. Authentication uses a NordVPN access token stored as a Podman secret (`nordvpn_token`).
- `transmission` container: shares the nordvpn network namespace (`--network container:nordvpn`), so all torrent peer traffic is bound to the VPN tunnel. RPC is published exclusively to `100.106.45.25:9091` (Tailscale interface). RPC authentication is disabled — Tailscale enforces access control.

Two subnets are allowlisted in NordVPN to bypass VPN routing: `10.88.0.0/16` (Podman bridge) and `100.64.0.0/10` (Tailscale CGNAT range), so the RPC port remains reachable over Tailscale.

`transmission.service` polls `nordvpn status` for up to 2 minutes waiting for `Status: Connected` before starting, and stops if nordvpn stops (`PartOf=nordvpn.service`). Both services start on boot and handle unclean shutdowns via pre-start container cleanup.

`tm.fish` on the Mac sends magnet links and torrents to the homelab at `$HOMELAB_HOST:9091` via `transmission-remote`.

## Key Fish Functions

| Function | Purpose |
|----------|---------|
| `vpn.fish` | [DEPRECATED] Formerly enforced VPN/Tailscale two-mode model; VPN now managed via GUI |
| `media.fish` | Homelab SMB mount with Tailscale connectivity check |
| `doctor.fish` | System health check: toolchain, mount status, Tailscale connectivity, macOS security flags |
| `snap.fish` | Rebuild `~/dev/snapshot.md` with live system data (censors IPs and credentials) |
| `tm.fish` | Send magnet links and torrents to homelab Transmission via `transmission-remote` |
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
