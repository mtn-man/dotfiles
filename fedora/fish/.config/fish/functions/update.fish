function update --description 'Update system packages via dnf and flatpak'
    sudo dnf upgrade --refresh; or return 1
    flatpak update -y; or return 1
    flatpak uninstall --unused -y

    echo (set_color normal --bold)"update complete"(set_color normal)
end
