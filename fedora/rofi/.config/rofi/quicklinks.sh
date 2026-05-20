#!/bin/bash
links="$HOME/.config/rofi/quicklinks"
if [[ "$ROFI_RETV" -eq 1 ]]; then
    url=$(awk -v k="$1" '$1==k{print $2}' "$links")
    [[ -n "$url" ]] && (sleep 0.1 && xdg-open "$url") >/dev/null 2>&1 &
else
    awk '{print $1}' "$links"
fi
