#!/usr/bin/env bash
# Install script for Fedora Sway setup.
# Run once from inside the dotfiles repo on a fresh Fedora install.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
info()    { printf '\e[34m=>\e[0m %s\n' "$*"; }
success() { printf '\e[32m✓\e[0m %s\n' "$*"; }
warn()    { printf '\e[33m!\e[0m %s\n' "$*"; }
die()     { printf '\e[31mERROR:\e[0m %s\n' "$*" >&2; exit 1; }

# install_extra PKG LABEL REPO_CMD... — skip if already installed, otherwise
# run REPO_CMD to add the source, then dnf install PKG.
install_extra() {
    local pkg=$1 label=$2; shift 2
    if rpm -q "$pkg" &>/dev/null; then
        success "$label already installed"
    else
        info "Installing $label..."
        "$@"
        sudo dnf install -y "$pkg"
        success "$label installed"
    fi
}

[[ $EUID -eq 0 ]] && die "Do not run this script as root"
[[ -f /etc/fedora-release ]] || die "This script is for Fedora only"

# -----------------------------------------------------------------------------
# 1. RPM Fusion
# -----------------------------------------------------------------------------
if rpm -q rpmfusion-free-release &>/dev/null && rpm -q rpmfusion-nonfree-release &>/dev/null; then
    success "RPM Fusion already enabled"
else
    fedora_ver=$(rpm -E %fedora)
    info "Enabling RPM Fusion repositories..."
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
    success "RPM Fusion enabled"
fi

# -----------------------------------------------------------------------------
# 2. Package installation
# -----------------------------------------------------------------------------
info "Installing packages..."

PKGS=(
    # --- System ---
    dnf-plugins-core

    # --- Shell ---
    fish

    # --- CLI tools ---
    eza
    bat
    fzf
    fd-find
    zoxide
    micro
    btop
    lazygit
    fastfetch
    tealdeer
    yt-dlp
    ffmpeg
    trash-cli
    stow

    # --- Desktop ---
    # Most of these ship with the Fedora Sway spin; listed for plain Fedora installs.
    kitty
    swaylock
    waybar
    rofi
    grim
    slurp
    sway-contrib
    wl-clipboard
    pavucontrol

    # --- Network ---
    network-manager-applet

    # --- Credentials / SSH ---
    openssh-askpass

    # --- Dev ---
    git
    golang

    # --- Fonts ---
    fira-code-fonts
    google-noto-emoji-fonts
)

MISSING=()
for pkg in "${PKGS[@]}"; do
    rpm -q "$pkg" &>/dev/null || MISSING+=("$pkg")
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    success "All packages already installed"
else
    sudo dnf install -y "${MISSING[@]}"
    success "Packages installed"
fi

# -----------------------------------------------------------------------------
# 3. Extra packages (not in official Fedora repos)
# -----------------------------------------------------------------------------
install_extra lf                  "lf"                 sudo dnf copr enable -y pennbauman/ports
install_extra firacode-nerd-fonts "FiraCode Nerd Font" sudo dnf copr enable -y atim/nerd-fonts
install_extra brave-origin-beta   "Brave browser"      sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo
install_extra tailscale           "Tailscale"          sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo

# -----------------------------------------------------------------------------
# 4. Stow dotfiles
# -----------------------------------------------------------------------------
info "Stowing dotfiles..."

PACKAGES=(fish lf micro kitty sway swaylock waybar yt-dlp fastfetch)

for pkg in "${PACKAGES[@]}"; do
    if [[ -d "$DOTFILES/$pkg" ]]; then
        stow -vt "$HOME" -d "$DOTFILES" "$pkg"
        success "Stowed $pkg"
    else
        warn "$pkg directory not found, skipping"
    fi
done

# -----------------------------------------------------------------------------
# 5. System services
# -----------------------------------------------------------------------------
info "Enabling system services..."

sudo systemctl enable --now tailscaled.service
success "System services enabled"

# -----------------------------------------------------------------------------
# 6. Default shell
# -----------------------------------------------------------------------------
if [[ "$SHELL" != "$(command -v fish)" ]]; then
    info "Setting fish as default shell..."
    fish_path=$(command -v fish)
    if ! grep -qF "$fish_path" /etc/shells; then
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$fish_path"
    success "Default shell set to fish (effective on next login)"
else
    success "fish is already the default shell"
fi

# -----------------------------------------------------------------------------
# 7. Font cache
# -----------------------------------------------------------------------------
info "Rebuilding font cache..."
fc-cache -f
success "Font cache rebuilt"

# -----------------------------------------------------------------------------
# 8. XDG user directories
# -----------------------------------------------------------------------------
info "Creating XDG user directories..."
xdg-user-dirs-update
mkdir -p "$HOME/Pictures/Screenshots"
if ! grep -q 'XDG_SCREENSHOTS_DIR' "$HOME/.config/user-dirs.dirs"; then
    echo 'XDG_SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"' >> "$HOME/.config/user-dirs.dirs"
fi
success "XDG user directories created"

# -----------------------------------------------------------------------------
# 9. Suppress login message
# -----------------------------------------------------------------------------
touch "$HOME/.hushlogin"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
printf '\n'
success "Install complete!"
printf '\n'
printf '  Next steps:\n'
printf '  1. Log out and back in so the shell change takes effect.\n'
printf '  2. Run: tailscale up        (authenticate Tailscale)\n'

printf '\n'
