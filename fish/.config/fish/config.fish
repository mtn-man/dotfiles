# 1. Environment Variables
set -gx EDITOR "micro"
set -gx VISUAL "micro"
set -gx VPN_SVC "NordVPN NordLynx"
set -gx HOMELAB_HOST "centos.tail586311.ts.net"
set -gx MEDIA_SHARE "media"
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
    source ~/.config/fish/aliases.fish
    source ~/.config/fish/abbrs.fish
    # zoxide init 
    if type -q zoxide
        zoxide init fish --cmd cd | source
      # zoxide init fish | source
    end
end
