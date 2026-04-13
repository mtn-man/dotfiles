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
# Homebrew (Apple Silicon) normalized paths
set -l brew_paths /opt/homebrew/bin /opt/homebrew/sbin
for p in $brew_paths
    set PATH (string match -vx $p $PATH)
end
fish_add_path -gP $brew_paths

# 3. Go Binary Path
fish_add_path -gP ~/go/bin

# 4. Interactive Session Configuration
if status is-interactive
    source ~/.config/fish/abbrs.fish
    # zoxide init 
    if type -q zoxide
        zoxide init fish --cmd cd | source
    end
end
