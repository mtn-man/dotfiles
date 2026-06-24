function fish_greeting
    set -l status_file ~/.local/state/doctor/status
    if test -f $status_file
        set -l lines (cat $status_file)
        set -l exit_code $lines[1]
        set -l summary $lines[2]
        if test "$exit_code" -gt 0
            printf 'doctor: %s\n\n' $summary
        end
    end
    echo "Welcome back to your server, Eli"
    fastfetch
end
