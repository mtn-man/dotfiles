function update --description 'Update system packages via dnf'
    sudo dnf upgrade --refresh; or return 1

    echo (set_color normal --bold)"update complete"(set_color normal)
end
