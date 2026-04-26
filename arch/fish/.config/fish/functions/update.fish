function update --description 'Update system packages via paru'
    if not command -q paru
        echo "update: paru not found; cannot continue" >&2
        return 127
    end

    paru -Syu; or return 1

    echo (set_color normal --bold)"update complete"(set_color normal)
end
