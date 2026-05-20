#!/bin/bash
links="$HOME/.config/rofi/quicklinks"
if [[ "$ROFI_RETV" -eq 1 ]]; then
    url=$(awk -v k="$1" '$1==k{print $2}' "$links")
    [[ -n "$url" ]] && (sleep 0.1 && xdg-open "$url") >/dev/null 2>&1 &
else
    icon=""
    [[ -f /usr/share/icons/hicolor/48x48/apps/brave-origin-beta.png ]] && icon="brave-origin-beta"
    awk -v icon="$icon" '{
        if (icon != "") printf "%s\0icon\x1f%s\n", $1, icon
        else print $1
    }' "$links"
fi
