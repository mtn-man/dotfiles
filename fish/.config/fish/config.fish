# 1. Environment Variables
set -gx EDITOR "micro"
set -gx VISUAL "micro"
set -g  VPN_SVC "NordVPN NordLynx"
set -g  HOMELAB_HOST "centos.tail586311.ts.net"
set -g  MEDIA_SHARE "media"
# Suppress Homebrew hints and cleanup messages
set -gx HOMEBREW_NO_ENV_HINTS 1
set -gx HOMEBREW_NO_INSTALL_CLEANUP 1

# 2. Homebrew Initialization 
# Homebrew (Apple Silicon) normalized paths
# path_helper (via brew shellenv) does not guarantee Homebrew paths are prepended,
# so we scrub any existing entries first and re-add them to the front of PATH,
# ensuring Homebrew tools take precedence over system equivalents.
set -l brew_paths /opt/homebrew/bin /opt/homebrew/sbin
for p in $brew_paths
    while contains $p $PATH
        set -e PATH[(contains -i $p $PATH)]
    end
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
