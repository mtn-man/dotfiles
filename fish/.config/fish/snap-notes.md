#System notes:
This snapshot provides a single-file view of the system configuration, useful
for recovery, human review, and giving AI assistants full context about this machine.

Full system backups are performed frequently to an air-gapped time machine SSD
(see doctor output for exact time since last backup).
My dotfiles are also backed up to a remote github repo.

stow-packages is the single source of truth for which packages get stowed:
bootstrap reads it to know what to stow, and doctor reads it to dry-run stow
and confirm everything is actually deployed. stow-add and stow-remove keep
it in sync automatically.

A CentOS Stream 10 homelab server is accessible over Tailscale, with SMB shares mounted on demand via Finder.

At my desk, a 40w underspecced charger is used to keep battery heat to a minumum.
This machine is not used for long-running intensive tasks when in this docked state.

Kitty is kept installed for its kitten icat image rendering; Ghostty is my primary terminal emulator.

On macOS, raw memory utilization is less meaningful than memory pressure — the OS aggressively
compresses inactive pages and reclaims memory on demand, so high utilization alone doesn't
indicate a problem.

Keybinds: Aside from the bindings recorded in the dotfiles, there are several other relevant keybinds:

    ctrl+option+arrows = window resizing actions (half screen) via Raycast (magnet-style bindings).
    ctrl+option={uijk} = window resizing (corners) -- via Raycast
    ctrl+option+return = maximize focused window -- via Raycast
    ctrl+option=m = almost maximize window -- via Raycast
    ctrl+shift+t = empty trash (no confirm) -- via Supercharge
    ctrl+shift+e = eject all external disks -- via Raycast
    ctrl+shift+n = clear system notifications -- via Supercharge (currently broken in macOS 27 beta)
    cmd+return = open Ghostty (hide if already in foreground) -- via Raycast
    ctrl+left/right = switch to previous/next Mission Control space -- native macOS
    ctrl+{1-9,0} = jump directly to Mission Control space 1-10 -- native macOS
    Raycast also has the CAPSLOCK key bound as my meta key for the bindings below.
    meta+f = search files
    meta+t = invokes my tm.fish function
    meta+k = open Google Keep in browser (my notes app)
    meta+y = open YouTube in browser
    meta+p = search Perplexity
    meta+m = search Google Maps
    meta+d = search DuckDuckGo (my preferred search engine)
    meta+j = open Jellyfin web client in browser (served from $HOMELAB)
    meta+c = open Claude AI in browser
    meta+g = open ChatGPT in browser
    meta+u = triggers the u abbr (brew update && upgrade && cleanup)
