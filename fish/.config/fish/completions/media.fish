complete -c media -f
complete -c media -n __fish_use_subcommand -a on -d 'Mount homelab share and start networking'
complete -c media -n __fish_use_subcommand -a off -d 'Unmount homelab share'
complete -c media -n '__fish_seen_subcommand_from on' -s l -l local -d 'Use local IP instead of Tailscale hostname'
