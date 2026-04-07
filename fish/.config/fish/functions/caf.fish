function caf --argument-names duration
    if test -z "$duration"
        echo "caf: usage - caf <duration> (e.g. caf 30m)" >&2
        return 1
    end

    dash -c 'after -c "$1"; say "caffeinate disabled; sleep re-enabled."' \
        _ "$duration" 2>/dev/null &
    disown $last_pid

    if not string match -qr '^[0-9]+[smh]$' -- $duration
        echo "caf: sleep prevented until $duration"
    else
        echo "caf: sleep prevented for $duration"
    end
end
