#!/usr/bin/env bash
if pgrep -x rofi > /dev/null; then
    pkill -x rofi
    exit
fi
choice=$(printf 'Shutdown\nRestart\nSleep\nLogout\nLock' | rofi -dmenu -p 'Power off?')
case "$choice" in
    'Shutdown')  systemctl poweroff ;;
    'Restart')   systemctl reboot ;;
    'Sleep')     systemctl suspend ;;
    'Logout')    swaymsg exit ;;
    'Lock')      swaylock -f ;;
esac
