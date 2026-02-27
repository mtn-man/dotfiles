function caf
    if test (count $argv) -eq 0
        echo "caf: usage - caf <duration> (e.g. caf 30m)"
        return 1
    end

    set duration $argv[1]
    fish -c "timer $duration -c 2>/dev/null; and say 'sleep re-enabled'" &
    disown $last_pid
    echo "caf: sleep prevention enabled for $duration"
end
