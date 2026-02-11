function fish_greeting
   # Only show fastfetch once per kitty window, not on every new shell
   # Prevents spam when using splits/tabs or when shell reloads
    if set -q KITTY_PID
       # Compare current window's PID against last greeted window
       # Universal variable persists across all fish instances
        if test "$fish_last_greeted_pid" != "$KITTY_PID"
            # Update the universal variable to the current PID
            set -U fish_last_greeted_pid "$KITTY_PID"

            echo "Welcome back, Eli"
            if type -q fastfetch
                fastfetch
            end
        end
    else
        # Fallback for SSH or other terminal emulators
        echo "Welcome back, Eli"
    end
end
