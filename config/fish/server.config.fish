if status is-interactive
    switch "$TERM"
        case tailscaled xterm-256
            set -gx TERM xterm-256color
    end

    set -g fish_greeting "Welcome back to your server, Eli"
    fastfetch

    set -gx EDITOR nano
    alias c='bat'
    alias ff='fastfetch'
    alias update='sudo dnf upgrade --refresh -y'
end

function drive-temp
    sudo smartctl -d sat -l scttemp /dev/sda | grep -E "Current Temperature|Max Temperature"
end
