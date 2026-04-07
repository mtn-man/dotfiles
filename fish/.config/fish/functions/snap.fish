function __snap_file --argument-names label path
    echo "$label:"
    echo
    cat $path
    echo
    echo "---"
    echo
end

function snap --description 'Rebuild ~/dev/sys-snapshot.txt with live data'
    set -l outfile ~/dev/sys-snapshot.txt
    set -l dotfiles ~/dev/dotfiles
    set -l sep "------------------------------------------------------------------------------------------"

    if not command -q fastfetch
        echo "snap: fastfetch not found" >&2
        return 127
    end

    begin
        # 1. System info
        fastfetch 2>/dev/null \
            | string replace -ra '\x1b\[[0-9;]*m' '' \
            | string replace -r 'Public IP:.*' 'Public IP: censored'

        echo
        echo "Battery health:"
        system_profiler SPPowerDataType | rg -i "cycle count|maximum capacity|condition" | string trim
        echo
        echo "System note: Full system backups are performed daily to an air-gapped time machine SSD. Dotfiles are also backed up to a private github repo and symlinked into place with GNU stow."
        echo "kitty is kept installed for its kitten icat image rendering; Ghostty is my primary terminal emulator."
        echo
        echo $sep
        echo

        # 2. Applications
        echo "/Applications:"
        ls /Applications
        echo
        echo "~/Applications:"
        ls ~/Applications
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
            echo "---"
            echo
            cat $f
            echo
        end
        echo $sep
        echo

        # 5. lf config
        __snap_file "~/.config/lf/lfrc" ~/.config/lf/lfrc
        __snap_file "~/.config/lf/pv.sh" ~/.config/lf/pv.sh
        __snap_file "~/.config/lf/clean.sh" ~/.config/lf/clean.sh
        echo $sep
        echo

        # 6. App configs
        __snap_file "~/.config/ghostty/config.ghostty" ~/.config/ghostty/config.ghostty
        __snap_file "~/.config/micro/bindings.json" ~/.config/micro/bindings.json
        __snap_file "~/.config/micro/settings.json" ~/.config/micro/settings.json
        __snap_file "~/.config/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc

    end > $outfile

    echo "snap: updated $outfile"
end
