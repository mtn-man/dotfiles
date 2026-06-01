#!/bin/bash
if pgrep -f "rofi -dmenu -p Empty Trash" > /dev/null; then
    pkill -f "rofi -dmenu -p Empty Trash"
    exit
fi
choice=$(printf 'Yes\nNo' | rofi -dmenu -p 'Empty Trash?')
[ "$choice" = 'Yes' ] && trash-empty -f
