complete -c vpn -f
complete -c vpn -n __fish_use_subcommand -a on     -d 'Enforce normal mode (VPN up, Tailscale down)'
complete -c vpn -n __fish_use_subcommand -a off    -d 'Enforce media mode (Tailscale up, VPN down)'
complete -c vpn -n __fish_use_subcommand -a status -d 'Show current network mode'
complete -c vpn -n __fish_use_subcommand -a toggle -d 'Switch between normal and media mode'
