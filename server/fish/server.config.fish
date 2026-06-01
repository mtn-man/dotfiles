fish_add_path -gP ~/bin
fish_add_path -gP ~/go/bin
if status is-interactive
    switch "$TERM"
        case tailscaled xterm-256
            set -gx TERM xterm-256color
    end

    set -g fish_greeting "Welcome back to your server, Eli"
    fastfetch

    set -gx EDITOR micro
    alias update='sudo dnf upgrade --refresh -y'
    abbr -a --global c 'bat'
    abbr -a --global mm 'mintmedia'
    abbr -a --global ts 'tailscale'
    abbr -a --global m 'micro'
    abbr -a --global ff 'fastfetch'
    abbr -a --global src 'source $__fish_config_dir/config.fish'
    abbr -a --global u 'update'
end

function drive-temp
    sudo smartctl -d sat -l scttemp /dev/sda | grep -E "Current Temperature|Max Temperature"
end
