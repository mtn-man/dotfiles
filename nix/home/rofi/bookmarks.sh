#!/usr/bin/env bash
bookmarks="$HOME/.config/rofi/bookmarks"
if [[ "$ROFI_RETV" -eq 1 ]]; then
    url=$(awk -v k="$1" '$1==k{print $2}' "$bookmarks")
    if [[ -n "$url" ]]; then
        systemd-run --user --no-block xdg-open "$url" >/dev/null 2>&1
        { sleep 0.3 && swaymsg '[app_id="firefox"] focus'; } >/dev/null 2>&1 &
    fi
else
    icon=""
    ff_icon=(/usr/share/icons/hicolor/48x48/apps/firefox*.png)
    [[ -f "${ff_icon[0]}" ]] && icon=$(basename "${ff_icon[0]}" .png)
    awk -v icon="$icon" '{
        if (icon != "") printf "%s\0icon\x1f%s\n", $1, icon
        else print $1
    }' "$bookmarks"
fi
