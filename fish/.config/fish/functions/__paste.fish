function __paste
    if command -q pbpaste
        pbpaste | string trim
    else if command -q wl-paste
        wl-paste 2>/dev/null | string trim
    end
end
