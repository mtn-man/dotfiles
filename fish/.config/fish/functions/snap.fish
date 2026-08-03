function __snap_file --argument-names label path lang
    echo "### $label"
    echo
    if test -f $path
        if test -n "$lang"
            echo '```'"$lang"
            cat $path
            echo
            echo '```'
        else
            cat $path
        end
    else
        echo "(file not found: $path)"
        set -ga __snap_errors $path
    end
    echo
    echo "---"
    echo
end

function snap --description 'Rebuild ~/dev/snapshots/snapshot-<date>.md with live data'
    set -l outfile ~/dev/snapshots/snapshot-(date +%Y-%m-%d).md
    set -l dotfiles ~/.dotfiles
    mkdir -p ~/dev/snapshots
    set -l snap_verb (test -f $outfile && echo updated || echo created)
    set -g __snap_errors

    if not command -q fastfetch
        echo "snap: fastfetch not found" >&2
        return 127
    end

    begin
        # 1. System info
        echo '```bash'
        fastfetch --logo none \
            | string replace -ra '\x1b\[[0-9;]*[A-Za-z]' '' \
            | string match -rv '█' \
            | string replace -r 'Public IP →.*' 'Public IP → censored'
        echo '```'

        echo
        echo "## Battery health"
        echo '```bash'
        system_profiler SPPowerDataType | rg -i "cycle count|maximum capacity|condition" | string trim
        echo '```'

        echo
        echo "## Memory pressure"
        echo '```bash'
        memory_pressure | rg "System-wide|Swapins|Swapouts|Pages used by compressor|Pages decompressed|Pages compressed" | string trim
        echo '```'

        echo
        echo "## System state"
        echo '```bash'
        doctor 2>&1 \
            | string replace -ra '\x1b\[[0-9;]*[A-Za-z]' '' \
            | string replace -r '(tailscale:\s+up) \([^)]+\)' '$1 (censored)' \
            | string replace -r '(exit node:\s+\S+) \([^)]+\)' '$1 (censored)'
        echo '```'

        echo
        if test -f $__fish_config_dir/snap-notes.md
            cat $__fish_config_dir/snap-notes.md
        else
            echo "snap: missing $__fish_config_dir/snap-notes.md" >&2
            set -ga __snap_errors $__fish_config_dir/snap-notes.md
        end
        echo

        # 2. Applications
        echo "## /Applications"
        echo '```bash'
        eza -1 /Applications
        echo '```'

        echo
        echo "## ~/Applications"
        echo '```bash'
        eza -1 ~/Applications
        echo '```'

        echo

        # 3. Dotfiles
        __snap_file "~/.dotfiles/Brewfile (also backed-up to dotfiles repo)" $dotfiles/Brewfile ruby
        __snap_file "~/.dotfiles/bootstrap" $dotfiles/bootstrap bash

        # 4. Fish config
        __snap_file "~/.config/fish/config.fish" $__fish_config_dir/config.fish fish
        __snap_file "~/.config/fish/abbrs.fish" $__fish_config_dir/abbrs.fish fish

        echo "The following reside in separate files within the ~/.config/fish/functions directory:"
        echo
        for f in $__fish_config_dir/functions/*.fish
            __snap_file "~/.config/fish/functions/"(basename $f) $f fish
        end

        echo "The following reside in separate files within the ~/.config/fish/completions directory:"
        echo
        for f in $__fish_config_dir/completions/*.fish
            __snap_file "~/.config/fish/completions/"(basename $f) $f fish
        end

        # 5. lf config
        __snap_file "~/.config/lf/lfrc" $dotfiles/lf/.config/lf/lfrc tex
        __snap_file "~/.config/lf/pv.sh" $dotfiles/lf/.config/lf/pv.sh bash
        __snap_file "~/.config/lf/clean.sh" $dotfiles/lf/.config/lf/clean.sh bash

        # 6. App configs
        __snap_file "~/Library/LaunchAgents/local.doctor.plist" $dotfiles/launchd/Library/LaunchAgents/local.doctor.plist xml
        __snap_file "~/.hammerspoon/init.lua" $dotfiles/hammerspoon/.hammerspoon/init.lua lua
        __snap_file "~/.config/ghostty/config.ghostty" $dotfiles/ghostty/.config/ghostty/config.ghostty tex
        __snap_file "~/.config/lazygit/config.yml" $dotfiles/lazygit/.config/lazygit/config.yml yaml
        __snap_file "~/.config/mintmedia/config.toml" $dotfiles/mintmedia/.config/mintmedia/config.toml toml
        __snap_file "~/.config/fastfetch/config.jsonc" $dotfiles/fastfetch/.config/fastfetch/config.jsonc jsonc
        __snap_file "~/.homebrew/trust.json" $dotfiles/homebrew/.homebrew/trust.json json
        __snap_file "~/.config/linearmouse/linearmouse.json" $dotfiles/linearmouse/.config/linearmouse/linearmouse.json json
        __snap_file "~/.vimrc" ~/.vimrc vim
        # .gitconfig is left out for security purposes.
        # btop.conf is left out: mostly default boilerplate, low signal.
    end \
        | string replace -a -- "$HOMELAB" 'censored' \
        | string replace -a -- "$HOMELAB_LOCAL" 'censored' \
        > $outfile

    echo "snap: $snap_verb $outfile"

    set -l old_snaps (ls -t ~/dev/snapshots/snapshot-*.md 2>/dev/null | tail -n +8)
    if set -q old_snaps[1]
        rm -- $old_snaps
    end

    if set -q __snap_errors[1]
        echo "snap: missing files:"
        for p in $__snap_errors
            echo "  $p"
        end
        set -e __snap_errors
        return 1
    end
    set -e __snap_errors
end
