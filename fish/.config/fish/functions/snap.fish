function __snap_file --argument-names label path
    echo "$label:"
    echo
    if test -f $path
        cat $path
    else
        echo "(file not found: $path)"
        set -ga __snap_errors $path
    end
    echo
    echo "---"
    echo
end

function snap --description 'Rebuild ~/dev/sys-snapshot.txt with live data'
    set -l outfile ~/dev/sys-snapshot.txt
    set -l dotfiles ~/dev/dotfiles
    set -l sep "------------------------------------------------------------------------------------------"
    set -g __snap_errors

    if not command -q fastfetch
        echo "snap: fastfetch not found" >&2
        return 127
    end

    begin
        # 1. System info
        fastfetch \
            | string replace -ra '\x1b\[[0-9;]*m' '' \
            | string match -rv '█' \
            | string replace -r 'Public IP →.*' 'Public IP → censored'

        echo
        echo "Battery health:"
        system_profiler SPPowerDataType | rg -i "cycle count|maximum capacity|condition" | string trim
        echo
        echo "Memory pressure:"
        memory_pressure | rg "System-wide|Swapins|Swapouts|Pages used by compressor|Pages decompressed|Pages compressed" | string trim
        echo
        echo "System state:"
        doctor 2>/dev/null \
            | string replace -ra '\x1b\[[0-9;]*m' '' \
            | string replace -r 'public IP: \S+' 'public IP: censored'
        echo
        echo "System note: This snapshot provides a single-file view of the system configuration, useful"
        echo "for recovery, human review, and giving AI assistants full context about this machine."
        echo "Full system backups are performed daily to an air-gapped time machine SSD."
        echo "Dotfiles are also backed up to a private github repo and symlinked into place with GNU stow."
        echo "A CentOS Stream 10 homelab is accessible over Tailscale, with SMB shares mounted on demand"
        echo "via the `media` function."
        echo "kitty is kept installed for its kitten icat image rendering;"
        echo "Ghostty is my primary terminal emulator."
        echo "On macOS, raw memory utilization is less meaningful than memory pressure — the OS aggressively"
        echo "compresses inactive pages and reclaims memory on demand, so high utilization alone doesn't"
        echo "indicate a problem."
        echo
        echo $sep
        echo

        # 2. Applications
        echo "/Applications:"
        ls -1 /Applications
        echo
        echo "~/Applications:"
        ls -1 ~/Applications
        echo
        echo $sep
        echo

        # 3. Dotfiles
        __snap_file "~/dotfiles/Brewfile (also backed-up to dotfiles repo)" $dotfiles/Brewfile
        __snap_file "~/dotfiles/README.md" $dotfiles/README.md
        __snap_file "~/dotfiles/setup.sh" $dotfiles/setup.sh
        echo $sep
        echo

        # 4. Fish config
        __snap_file "~/.config/fish/config.fish" $__fish_config_dir/config.fish
        __snap_file "~/.config/fish/abbrs.fish" $__fish_config_dir/abbrs.fish

        echo "The following reside in separate files within the ~/.config/fish/functions directory:"
        echo
        for f in $__fish_config_dir/functions/*.fish
            __snap_file "~/.config/fish/functions/"(basename $f) $f
        end
        echo $sep
        echo

        # 5. lf config
        __snap_file "~/.config/lf/lfrc" $dotfiles/lf/.config/lf/lfrc
        __snap_file "~/.config/lf/pv.sh" $dotfiles/lf/.config/lf/pv.sh
        __snap_file "~/.config/lf/clean.sh" $dotfiles/lf/.config/lf/clean.sh
        echo $sep
        echo

        # 6. App configs
        __snap_file "~/.config/ghostty/config.ghostty" $dotfiles/ghostty/.config/ghostty/config.ghostty
        __snap_file "~/.config/micro/bindings.json" $dotfiles/micro/.config/micro/bindings.json
        __snap_file "~/.config/micro/settings.json" $dotfiles/micro/.config/micro/settings.json
        __snap_file "~/.config/fastfetch/config.jsonc" $dotfiles/fastfetch/.config/fastfetch/config.jsonc
        __snap_file "/opt/homebrew/var/transmission/settings.json" ~/dev/transmission/settings.json

    end > $outfile

    echo "snap: updated $outfile"

    if set -q __snap_errors[1]
        echo "snap: missing files:"
        for p in $__snap_errors
            echo "  $p"
        end
    end
    set -e __snap_errors
end
