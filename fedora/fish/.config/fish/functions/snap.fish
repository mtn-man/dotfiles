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

function snap --description 'Rebuild ~/dev/snapshot.md with live data'
    set -l outfile ~/dev/snapshot.md
    set -l dotfiles ~/dev/dotfiles/fedora
    set -g __snap_errors

    if not command -q fastfetch
        echo "snap: fastfetch not found" >&2
        return 127
    end

    begin
        # 1. System info
        echo '```bash'
        fastfetch \
            | string replace -ra '\x1b\[[0-9;]*[A-Za-z]' '' \
            | string match -rv '█'
        echo '```'

        echo
        echo "## Battery"
        echo '```bash'
        set -l bat_path (upower -e 2>/dev/null | grep -i battery | head -1)
        if test -n "$bat_path"
            upower -i $bat_path | grep -E "state|percentage|energy-full|capacity|time to|cycle" | string trim
        else
            echo "(no battery found)"
        end
        echo '```'

        echo
        echo "## Memory"
        echo '```bash'
        free -h
        echo '```'

        echo
        echo "System note: Fedora 44 Sway spin on ThinkPad T14 Gen 1 (i5-10210U, 16GB RAM)."
        echo "Dotfiles managed with GNU Stow from ~/dev/dotfiles/fedora/."
        echo "Packages stowed: fish, lf, micro, kitty, sway, swaylock, waybar, rofi, fastfetch, yt-dlp."
        echo "Tailscale is the only VPN on this machine — no NordVPN."
        echo "Notification daemon is dunst; idle/lock is swayidle — both provided by the Fedora Sway spin."
        echo "Full package list is in fedora-bootstrap.sh."
        echo

        # 2. Installed packages
        echo "## DNF user-installed packages"
        echo '```bash'
        dnf repoquery --userinstalled --cacheonly --qf "%{name}\n" 2>/dev/null | sort | pr -3 -t -w 120
        echo '```'

        echo
        echo "## Flatpak apps"
        echo '```bash'
        flatpak list --app --columns=name,application,version 2>/dev/null; or echo "(flatpak not available)"
        echo '```'

        echo

        # 3. Bootstrap
        __snap_file "~/dev/dotfiles/fedora/fedora-bootstrap.sh" $dotfiles/fedora-bootstrap.sh bash

        # 4. Fish config
        __snap_file "~/.config/fish/config.fish" $__fish_config_dir/config.fish fish
        __snap_file "~/.config/fish/abbrs.fish" $__fish_config_dir/abbrs.fish fish

        echo "The following reside in separate files within the ~/.config/fish/functions directory:"
        echo
        for f in $__fish_config_dir/functions/*.fish
            __snap_file "~/.config/fish/functions/"(basename $f) $f fish
        end

        # 5. lf config
        __snap_file "~/.config/lf/lfrc" ~/.config/lf/lfrc text
        __snap_file "~/.config/lf/pv.sh" ~/.config/lf/pv.sh bash
        __snap_file "~/.config/lf/clean.sh" ~/.config/lf/clean.sh bash

        # 6. App configs
        __snap_file "~/.config/kitty/kitty.conf" ~/.config/kitty/kitty.conf text
        __snap_file "~/.config/micro/settings.json" ~/.config/micro/settings.json json
        __snap_file "~/.config/micro/bindings.json" ~/.config/micro/bindings.json json
        __snap_file "~/.config/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc jsonc

        # 7. Sway stack
        __snap_file "~/.config/sway/config" ~/.config/sway/config text
        __snap_file "~/.config/sway/config.d/90-swayidle.conf" ~/.config/sway/config.d/90-swayidle.conf text
        __snap_file "~/.config/sway/power-menu.sh" ~/.config/sway/power-menu.sh bash
        __snap_file "~/.config/swaylock/config" ~/.config/swaylock/config text
        __snap_file "~/.config/waybar/config.jsonc" ~/.config/waybar/config.jsonc jsonc
        __snap_file "~/.config/waybar/style.css" ~/.config/waybar/style.css css

        __snap_file "~/.config/autostart/nm-applet.desktop" ~/.config/autostart/nm-applet.desktop text

        # 8. rofi
        __snap_file "~/.config/rofi/config.rasi" ~/.config/rofi/config.rasi text
        __snap_file "~/.config/rofi/links" ~/.config/rofi/links text
        __snap_file "~/.config/rofi/links.sh" ~/.config/rofi/links.sh bash
        __snap_file "~/.config/rofi/functions" ~/.config/rofi/functions text
        __snap_file "~/.config/rofi/functions.sh" ~/.config/rofi/functions.sh bash

        # 9. yt-dlp
        __snap_file "~/.config/yt-dlp/config" ~/.config/yt-dlp/config text

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
