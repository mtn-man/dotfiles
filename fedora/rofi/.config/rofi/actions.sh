#!/bin/bash
actions_file="$HOME/.config/rofi/actions"

if [[ "$ROFI_RETV" -eq 1 ]]; then
    if [[ "$ROFI_INFO" == "silent" ]]; then
        systemd-run --user --no-block fish -c "$1; dunstify '$1'" >/dev/null 2>&1
    else
        systemd-run --user --no-block kitty fish -c "$1; exec fish" >/dev/null 2>&1
    fi
else
    icon=""
    kitty_icon=(/usr/share/icons/hicolor/*/apps/kitty.png)
    [[ -f "${kitty_icon[0]}" ]] && icon=$(basename "${kitty_icon[0]}" .png)
    while IFS= read -r line; do
        if [[ "$line" == *"~" ]]; then
            name="${line%\~}"
            info="silent"
        else
            name="$line"
            info="persist"
        fi
        if [[ -n "$icon" ]]; then
            printf "%s\0icon\x1f%s\x1finfo\x1f%s\n" "$name" "$icon" "$info"
        else
            printf "%s\0info\x1f%s\n" "$name" "$info"
        fi
    done < "$actions_file"
fi
