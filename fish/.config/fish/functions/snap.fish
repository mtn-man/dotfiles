function snap --description 'Rebuild ~/dev/sys-snapshot.txt with live data'
    set -l outfile ~/dev/sys-snapshot.txt
    set -l dotfiles ~/dev/dotfiles
    set -l fishcfg ~/.config/fish
    set -l sep "------------------------------------------------------------------------------------------"
    set -l thin "---"

    if not command -q fastfetch
        echo "snap: fastfetch not found" >&2
        return 127
    end

    rm -f $outfile

    begin
        # 1. fastfetch header (public IP censored, ANSI codes stripped)
        fastfetch 2>/dev/null \
            | string replace -ra '\x1b\[[0-9;]*m' '' \
            | string replace -r 'Public IP:.*' 'Public IP: censored'

        echo
        echo "System note: Full system backups are performed daily to an air-gapped time machine SSD. Dotfiles are also backed up to a private github repo and symlinked into place with GNU stow."
        echo

        # 2. Brewfile
        echo "~/dotfiles/Brewfile (also backed-up to dotfiles repo):"
        echo
        cat $dotfiles/Brewfile
        echo
        echo $thin
        echo

        # 3. Applications listings
        echo "/Applications:"
        ls /Applications
        echo
        echo "~/Applications:"
        ls ~/Applications
        echo

        echo $sep
        echo

        # 4. Fish config files
        echo "~/.config/fish/config.fish:"
        echo
        cat $fishcfg/config.fish
        echo
        echo $sep
        echo

        cat $fishcfg/aliases.fish
        echo
        echo $sep
        echo

        echo "The following reside in separate files within the ~/.config/fish/functions directory:"
        echo

        for f in $fishcfg/functions/*.fish
            echo $thin
            echo
            cat $f
            echo
        end

        echo $sep
        echo

        # 5. lf config
        echo "~/.config/lf/lfrc:"
        echo
        cat ~/.config/lf/lfrc
        echo

        echo $thin
        echo "~/.config/lf/pv.sh:"
        echo
        cat ~/.config/lf/pv.sh

        echo $thin
        echo
        echo "~/.config/lf/clean.sh:"
        echo
        cat ~/.config/lf/clean.sh
        echo

        # 6. Ghostty config
        echo $thin
        echo
        echo "~/.config/ghostty/config.ghostty:"
        echo
        cat ~/.config/ghostty/config.ghostty
        echo

        # 7. Micro configs
        echo $thin
        echo
        echo "~/.config/micro/bindings.json:"
        cat ~/.config/micro/bindings.json
        echo

        echo $thin
        echo
        echo "~/.config/micro/settings.json:"
        cat ~/.config/micro/settings.json
        echo

        # 8. Fastfetch config
        echo $thin
        echo
        echo "~/.config/fastfetch/config.jsonc:"
        echo
        cat ~/.config/fastfetch/config.jsonc
        echo

        echo $sep
        echo

        # 9. Timer source
        echo "My custom go timer binary:"
        echo
        cat ~/dev/golang/timer/main.go

    end >> $outfile

    echo "snap: updated $outfile"
end
