#!/usr/bin/env bash
places="$HOME/.config/rofi/places"
if [[ "$ROFI_RETV" -eq 1 ]]; then
    path=$(awk -v k="$1" '$1==k{print $2}' "$places")
    if [[ -n "$path" ]]; then
        expanded="${path/#\~/$HOME}"
        systemd-run --user --no-block kitty fish -c "cd '$expanded'; exec fish" >/dev/null 2>&1
    fi
else
    icon=""
    kitty_icon=(/run/current-system/sw/share/icons/hicolor/*/apps/kitty.png)
    [[ -f "${kitty_icon[0]}" ]] && icon=$(basename "${kitty_icon[0]}" .png)
    while read -r name path; do
        [[ -z "$name" ]] && continue
        if [[ -n "$icon" ]]; then
            printf "%s\0icon\x1f%s\n" "$name" "$icon"
        else
            echo "$name"
        fi
    done < "$places"
fi
