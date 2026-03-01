function caf --argument-names duration
    if test -z "$duration"
        echo "caf: usage - caf <duration> (e.g. caf 30m)" >&2
        return 1
    end

    dash -c 'timer -c "$1"; say "caffeinate disabled; sleep re-enabled."' _ "$duration" 2>/dev/null &
    disown $last_pid

    echo "caf: sleep prevented for $duration"
end
