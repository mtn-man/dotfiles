# 1. Environment Variables
set -gx EDITOR "micro"
set -g  HOMELAB "100.106.45.25"
set -g  HOMELAB_LOCAL "192.168.0.43"
set -g  MEDIA_SHARE "media"
# Suppress Homebrew hints and cleanup messages
set -gx HOMEBREW_NO_ENV_HINTS 1
set -gx HOMEBREW_NO_INSTALL_CLEANUP 1
# Require explicit trust for Homebrew taps
set -gx HOMEBREW_REQUIRE_TAP_TRUST 1

# 2. Homebrew Initialization
# Homebrew (Apple Silicon):
# ensure /opt/homebrew/{bin,sbin} are at the front of PATH.
fish_add_path -gPm /opt/homebrew/bin /opt/homebrew/sbin

# 3. Go Binary Path
fish_add_path -gP ~/go/bin

set -x GPG_TTY (tty)

# 4. Interactive Session Configuration
if status is-interactive
    source ~/.config/fish/abbrs.fish
    # zoxide init
    command -q zoxide; and zoxide init fish --cmd cd | source
end
