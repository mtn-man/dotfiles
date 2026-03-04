function fish_greeting
    # Only show fastfetch once per terminal session key, not every subshell.
    # Prefer terminal-emulator process IDs for stable tracking.
    set -l terminal_key
    set -l is_ghostty 0

    if set -q TERM_PROGRAM; and test "$TERM_PROGRAM" = "ghostty"
        set is_ghostty 1
    else if set -q GHOSTTY_RESOURCES_DIR
        set is_ghostty 1
    end

    # Ghostty first (trust only numeric PID values).
    if set -q GHOSTTY_PID; and string match -rq -- '^[0-9]+$' "$GHOSTTY_PID"
        set terminal_key "ghostty:$GHOSTTY_PID"
    # Keep kitty support during transition.
    else if set -q KITTY_PID; and string match -rq -- '^[0-9]+$' "$KITTY_PID"
        set terminal_key "kitty:$KITTY_PID"
    # Fallback for Ghostty: walk process ancestry to find a ghostty PID.
    else if test "$is_ghostty" -eq 1
        set -l probe_pid $fish_pid
        while string match -rq -- '^[0-9]+$' "$probe_pid"; and test "$probe_pid" -gt 1
            set -l probe_comm (ps -o comm= -p "$probe_pid" 2>/dev/null | string trim | string lower)
            if string match -q -- "*ghostty*" "$probe_comm"
                set terminal_key "ghostty:$probe_pid"
                break
            end
            set probe_pid (ps -o ppid= -p "$probe_pid" 2>/dev/null | string trim)
        end

        # Last-resort fallback when ancestry inspection is unavailable.
        if test -z "$terminal_key"
            set -l tty_path (tty 2>/dev/null | string trim)
            if string match -q -- "/dev/*" "$tty_path"
                set terminal_key "ghostty:$tty_path"
            end
        end
    end

    if test -n "$terminal_key"
        # Universal variable persists across all fish instances.
        if test "$fish_last_greeted_pid" != "$terminal_key"
            set -U fish_last_greeted_pid "$terminal_key"

            echo "Welcome back, Eli"
            if type -q fastfetch
                fastfetch
            end
        end
    else
        # Fallback for SSH or unsupported terminal emulators.
        echo "Welcome back, Eli"
    end
end
