# 1. Environment Variables
set -gx EDITOR "micro"
set -gx VISUAL "micro"
# Suppress Homebrew hints and cleanup messages
set -gx HOMEBREW_NO_ENV_HINTS 1
set -gx HOMEBREW_NO_INSTALL_CLEANUP 1

# 2. Homebrew Initialization 
# Homebrew (Apple Silicon)
set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
set -gx HOMEBREW_REPOSITORY /opt/homebrew

fish_add_path -gP /opt/homebrew/bin
fish_add_path -gP /opt/homebrew/sbin

set -gx MANPATH /opt/homebrew/share/man $MANPATH
set -gx INFOPATH /opt/homebrew/share/info $INFOPATH

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
    alias tm-re='brew services restart transmission-cli'
    alias z='cd'
    alias speed='networkQuality'
    alias lg='lazygit'
end

# 5. Zoxide alias
zoxide init fish --cmd cd | source
