# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for macOS (primary) and a CentOS Stream 10 homelab (`server/`). Deployed via GNU Stow.

## Deployment

```fish
# Deploy a single package
stow -vt $HOME fish

# Deploy all packages
stow -vt $HOME */
```

Each package follows XDG convention: `<package>/.config/<package>/` → `~/.config/<package>/`.

The `server/` directory is not stow-deployed; its Fish config is sourced manually on the homelab.

## Package Installation

```fish
brew bundle install   # install all tools from Brewfile
```

## Architecture

- **`fish/`** — Primary shell config: `config.fish` (env vars), `abbrs.fish` (abbreviations), and `functions/` (19 custom functions)
- **`ghostty/`** / **`kitty/`** — Terminal emulator configs
- **`micro/`** — Editor config (Solarized theme, Go tool keybindings in `bindings.json`)
- **`lf/`** — File manager config with zoxide integration and preview/clean scripts
- **`mintmedia/`** — Config for the `mintmedia` Go tool (media file organizer, watch folder → destination rules)
- **`fastfetch/`** — System info display config
- **`server/`** — CentOS homelab: Fish config + `server.backup.sh` (rsync cold backup script)

## Key Fish Functions

| Function | Purpose |
|----------|---------|
| `vpn.fish` | VPN on/off/status via macOS `scutil --nc` |
| `media.fish` | Orchestrates homelab SMB mount + Tailscale + Transmission |
| `update.fish` | Homebrew upgrade wrapper |
| `yt.fish` | YouTube download via yt-dlp |
| `fm.fish` | File search + edit (fd + fzf + micro) |
| `tm.fish` | Transmission-CLI service management and magnet link handler |
| `gr.fish` | Git repo discovery and navigation |
| `gcp.fish` | Stage all, commit (message or editor), and push |
| `fish_prompt.fish` | Custom prompt with git status indicators |
| `fish_right_prompt.fish` | Shows elapsed time for commands over threshold |
| `fish_greeting.fish` | Welcome message + fastfetch, once per terminal window |
| `lf.fish` | Wraps lf with quit-and-cd integration |
| `snap.fish` | Rebuilds `~/dev/sys-snapshot.txt` with live system data |
| `caf.fish` | Prevents sleep for a duration via `after` |
| `stow-add.fish` | Moves a `~/.config` package into dotfiles and stows it |
| `mkcd.fish` | Creates a directory and cd into it |
| `lp.fish` | Lists PATH entries with existence check |
| `mp3sort.fish` | Organizes MP3s from `Artist - Album - Track` into folders |
| `__abbr_timer_minutes.fish` | Helper expanding `a15` → `after 15m` abbreviations |

## Git-ignored Paths

Fish shell state (`fish_history`, `fish_variables`, `conf.d/`), micro editor buffers/history, and `.DS_Store` files are excluded from version control.
