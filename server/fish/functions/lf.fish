function lf --description 'lf with quit-and-cd integration'
    set -l tmp (mktemp)

    if test -z "$tmp"
        set tmp "/tmp/lf-last-dir-$fish_pid"
        command touch "$tmp" 2>/dev/null
    end

    command lf -last-dir-path="$tmp" $argv
    set -l lf_status $status

    if test -f "$tmp"
        read -l dir < "$tmp"

        if test -n "$dir"; and test -d "$dir"; and test "$dir" != (pwd)
            cd -- "$dir"
        end
    end

    rm -f "$tmp"

    return $lf_status
end
