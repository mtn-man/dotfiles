# 1. Environment Variables
set -gx EDITOR "micro"
set -gx VISUAL "micro"
set -g  VPN_SVC "NordVPN NordLynx"
set -g  HOMELAB_HOST "100.106.45.25"
set -g  MEDIA_SHARE "media"
# Suppress Homebrew hints and cleanup messages
set -gx HOMEBREW_NO_ENV_HINTS 1
set -gx HOMEBREW_NO_INSTALL_CLEANUP 1

# 2. Homebrew Initialization 
# Homebrew (Apple Silicon): ensure /opt/homebrew/{bin,sbin} are at the front of
# PATH. fish_add_path -m moves existing entries rather than duplicating them,
# which guarantees Homebrew tools take precedence over system equivalents even
# if path_helper (via brew shellenv) added them in a later position.
fish_add_path -gPm /opt/homebrew/bin /opt/homebrew/sbin

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
