#!/bin/bash
functions_file="$HOME/.config/rofi/actions"

if [[ "$ROFI_RETV" -eq 1 ]]; then
    systemd-run --user --no-block kitty fish -c "$1; exec fish" >/dev/null 2>&1
else
    icon=""
    kitty_icon=(/usr/share/icons/hicolor/*/apps/kitty.png)
    [[ -f "${kitty_icon[0]}" ]] && icon=$(basename "${kitty_icon[0]}" .png)
    while IFS= read -r name; do
        if [[ -n "$icon" ]]; then
            printf "%s\0icon\x1f%s\n" "$name" "$icon"
        else
            echo "$name"
        fi
    done < "$functions_file"
fi
