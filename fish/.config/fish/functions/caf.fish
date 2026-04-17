function caf --argument-names duration
    # after -c specifically integrates with macOS caffeinate and ties it to the after timer PID
    if not set -q duration
        echo "caf: usage - caf <duration> (e.g. caf 30m)" >&2
        return 1
    end

    /bin/sh -c 'after -c "$1"; say "caffeinate disabled; sleep re-enabled."' \
        _ "$duration" 2>/dev/null &
    disown

    if not string match -qr '^[0-9]+[smh]$' -- $duration
        echo "caf: sleep prevented until $duration"
    else
        echo "caf: sleep prevented for $duration"
    end
end
