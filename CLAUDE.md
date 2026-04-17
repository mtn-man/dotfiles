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

## Bootstrap

`bootstrap.sh` in the repo root bootstraps a new macOS machine: installs Brewfile packages, sets Fish as the default shell, stows all dotfile packages, suppresses the login message, and applies macOS defaults (dock, key repeat, window drag).

## Architecture

- **`fish/`** — Primary shell config: `config.fish` (env vars), `abbrs.fish` (abbreviations), and `functions/` (18 custom functions)
- **`ghostty/`** — Terminal emulator config
- **`micro/`** — Editor config (Solarized theme, Go tool keybindings in `bindings.json`)
- **`lf/`** — File manager config with zoxide integration and preview/clean scripts
- **`mintmedia/`** — Config for the `mintmedia` Go tool (media file organizer, watch folder → destination rules)
- **`fastfetch/`** — System info display config
- **`server/`** — CentOS homelab: Fish config + `server.backup.sh` (rsync cold backup script)

## Key Fish Functions

| Function | Purpose |
|----------|---------|
| `vpn.fish` | VPN on/off/status via macOS `scutil --nc` |
| `media.fish` | Manages Tailscale connection and homelab SMB mount |
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
| `snap.fish` | Rebuilds `~/dev/snapshot.md` with live system data |
| `caf.fish` | Prevents sleep for a duration via `after` |
| `stow-add.fish` | Moves a `~/.config` package into dotfiles and stows it |
| `mkcd.fish` | Creates a directory and cd into it |
| `lp.fish` | Lists PATH entries with existence check |
| `__abbr_timer_minutes.fish` | Helper expanding `a15` → `after 15m` abbreviations |

## Git Workflow

Never create commits unless explicitly instructed to. The user reviews all changes before committing.

## Git-ignored Paths

Fish shell state (`fish_history`, `fish_variables`, `conf.d/`), micro editor buffers/history, and `.DS_Store` files are excluded from version control.
