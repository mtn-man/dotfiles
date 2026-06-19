complete -c writeiso -f
complete -c writeiso -s n -l dry-run -d 'Complete all steps but skip the actual write'
complete -c writeiso -s h -l help    -d 'Show help'
complete -c writeiso -a "(__fish_complete_suffix .iso)"
