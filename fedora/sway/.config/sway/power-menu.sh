#!/bin/bash
if pgrep -f "rofi -dmenu -p Power off" > /dev/null; then
    pkill -f "rofi -dmenu -p Power off"
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
