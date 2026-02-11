# 1. Environment Variables
set -gx EDITOR "micro"
set -gx VISUAL "micro"
# Suppress Homebrew hints and cleanup messages
set -gx HOMEBREW_NO_ENV_HINTS 1
set -gx HOMEBREW_NO_INSTALL_CLEANUP 1

# 2. Homebrew Initialization 
# Using eval is the most reliable way to ensure all Homebrew variables (PATH, MANPATH, etc.) are set correctly.
if test -d /opt/homebrew
    eval (/opt/homebrew/bin/brew shellenv)
end

# 3. Go Binary Path
fish_add_path -gP ~/go/bin

# 4. Interactive Session Configuration
if status is-interactive
    # Using alias instead of abbr for internal function compatibility
    alias u='update'
    alias t='timer'
    alias t3='timer 3m'
    alias t4='timer 4m'
    alias t5='timer 5m'
    alias t10='timer 10m'
    alias t20='timer 20m'
    alias t30='timer 30m'
    alias mm='mintmedia'
    alias m='micro'
    alias mn='media-on'
    alias mf='media-off'
    alias nu='nord-up'
    alias nd='nord-down'
    alias l='eza'
    alias c='bat'
    alias ff='fastfetch'
    alias yto='yt -o'
    alias yti='yt -i'
    alias tm-on='brew services start transmission-cli'
    alias tm-off='brew services stop transmission-cli'
    alias tm-re 'brew services restart transmission-cli'
end

# 5. Functions
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

# 6. Zoxide init
zoxide init fish --cmd cd | source
