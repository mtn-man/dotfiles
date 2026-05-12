function batt
    upower -i (upower -e | grep BAT) | grep -v "History\|^\s*[0-9]"
end
