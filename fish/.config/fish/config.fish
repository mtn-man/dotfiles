# 1. Environment Variables
set -gx EDITOR "vim"
set -g  MEDIA_SHARE "media"
# Host-specific secrets/IPs (gitignored, not tracked) — see env.fish.example
if test -f ~/.config/fish/env.fish
    source ~/.config/fish/env.fish
end
set -gx LG_CONFIG_FILE ~/.config/lazygit/config.yml
# Suppress Homebrew hints and cleanup messages
set -gx HOMEBREW_NO_ENV_HINTS 1
set -gx HOMEBREW_NO_INSTALL_CLEANUP 1
# Require explicit trust for Homebrew taps
set -gx HOMEBREW_REQUIRE_TAP_TRUST 1

# 2. Homebrew Initialization
# Homebrew (Apple Silicon):
# move /opt/homebrew/{bin,sbin} to the front of PATH, ahead of system paths.
fish_add_path -gPm /opt/homebrew/bin /opt/homebrew/sbin

# 3. Go Binary Path
# Prepended after Homebrew so ~/go/bin shadows same-named Homebrew formulae,
# for testing locally-built Go tools.
fish_add_path -gP ~/go/bin

# 4. Interactive Session Configuration
if status is-interactive
    source ~/.config/fish/abbrs.fish
    # zoxide init
    command -q zoxide; and zoxide init fish --cmd cd | source
    set -x GPG_TTY (tty)
end
