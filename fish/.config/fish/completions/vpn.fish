complete -c vpn -f
complete -c vpn -n __fish_use_subcommand -a on     -d 'Enforce VPN mode (VPN up, Tailscale down)'
complete -c vpn -n __fish_use_subcommand -a off    -d 'Enforce Tailscale mode (Tailscale up, VPN down)'
complete -c vpn -n __fish_use_subcommand -a status -d 'Show current network mode'
complete -c vpn -n __fish_use_subcommand -a toggle -d 'Switch between VPN and Tailscale mode'
