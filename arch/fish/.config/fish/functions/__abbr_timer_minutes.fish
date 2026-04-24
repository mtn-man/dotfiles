function __abbr_timer_minutes --argument token
    set -l minutes (string match -r --groups-only '^a([1-9][0-9]*)$' -- $token)
    or return 1
    printf 'after %sm\n' "$minutes"
end
