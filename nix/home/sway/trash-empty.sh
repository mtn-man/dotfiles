#!/bin/bash
if pgrep -x rofi > /dev/null; then
    pkill -x rofi
    exit
fi
choice=$(printf 'Yes\nNo' | rofi -dmenu -p 'Empty Trash?')
[ "$choice" = 'Yes' ] && trash-empty -f
