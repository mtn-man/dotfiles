#!/bin/bash
links="$HOME/.config/rofi/links"
if [[ "$ROFI_RETV" -eq 1 ]]; then
    url=$(awk -v k="$1" '$1==k{print $2}' "$links")
    if [[ -n "$url" ]]; then
        systemd-run --user --no-block xdg-open "$url" >/dev/null 2>&1
        { sleep 0.3 && swaymsg '[app_id="^brave"] focus'; } >/dev/null 2>&1 &
    fi
else
    icon=""
    brave_icon=(/usr/share/icons/hicolor/48x48/apps/brave*.png)
    [[ -f "${brave_icon[0]}" ]] && icon=$(basename "${brave_icon[0]}" .png)
    awk -v icon="$icon" '{
        if (icon != "") printf "%s\0icon\x1f%s\n", $1, icon
        else print $1
    }' "$links"
fi
