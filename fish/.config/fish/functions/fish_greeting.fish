function fish_greeting --description 'Display welcome message once per terminal window'
    set -l terminal_key

    if set -q GHOSTTY_RESOURCES_DIR
        # Walk ancestry to find the Ghostty process PID, which is stable
        # across all tabs in a window
        set -l probe_pid $fish_pid
        while string match -rq -- '^[0-9]+$' "$probe_pid"; and \
                test "$probe_pid" -gt 1
            set -l probe_comm (ps -o comm= -p "$probe_pid" 2>/dev/null \
                | string trim | string lower)
            if string match -q -- "*ghostty*" "$probe_comm"
                set terminal_key "ghostty:$probe_pid"
                break
            end
            set probe_pid (ps -o ppid= -p "$probe_pid" 2>/dev/null \
                | string trim)
        end
    else if set -q KITTY_PID; and \
            string match -rq -- '^[0-9]+$' "$KITTY_PID"
        set terminal_key "kitty:$KITTY_PID"
    end

    if test -n "$terminal_key"; and \
            test "$fish_last_greeted_pid" != "$terminal_key"
        set -U fish_last_greeted_pid "$terminal_key"
        echo "Welcome back, Eli"
        command -q fastfetch; and fastfetch
    else if test -z "$terminal_key"
        echo "Welcome back, Eli"
    end
end
