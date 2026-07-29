fish_add_path -gP ~/bin
fish_add_path -gP ~/go/bin

if status is-interactive
    switch "$TERM"
        case tailscaled xterm-256
            set -gx TERM xterm-256color
    end

    set -gx SYSTEMD_PAGER cat
    set -gx EDITOR vim
    # zoxide init -- remaps cd itself, matching the Mac config
    command -q zoxide; and zoxide init fish --cmd cd | source
    #abbrs
    abbr -a --global u 'sudo dnf upgrade --refresh -y'
    abbr -a --global dr 'doctor'
    abbr -a --global mm 'mintmedia'
    abbr -a --global c 'bat'
    abbr -a --global ts 'tailscale status'
    abbr -a --global m 'vim -y'
    abbr -a --global ff 'fastfetch'
    abbr -a --global src 'source $__fish_config_dir/config.fish'
    abbr -a --global v 'vim'
    abbr -a --global lg 'lazygit'
end
