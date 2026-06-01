#!/usr/bin/env bash
# Install script for Fedora Sway setup.
# Run once from inside the dotfiles repo on a fresh Fedora install.
set -uo pipefail

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
    gh
    transmission-cli
    bc
    tree
    rsync
    unzip
    zip
    nmap-ncat
    wev
    nvme-cli
    smartmontools
    nodejs22
    playerctl

    # --- Desktop ---
    # Most of these ship with the Fedora Sway spin; listed for plain Fedora installs.
    kitty
    swaylock
    swayidle
    waybar
    rofi
    grim
    slurp
    sway-contrib
    wl-clipboard
    pavucontrol
    kanshi
    nwg-wrapper
    imv
    mpv

    # --- Network ---
    network-manager-applet

    # --- Credentials / SSH ---
    openssh-askpass

    # --- Dev ---
    git
    golang
    gopls

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
    info "Installing packages..."
    sudo dnf install -y "${MISSING[@]}"
    success "Packages installed"
fi

# -----------------------------------------------------------------------------
# 3. Extra packages (not in official Fedora repos)
# -----------------------------------------------------------------------------
install_extra lf                  "lf"                 sudo dnf copr enable -y lsevcik/lf
if rpm -q firacode-nerd-fonts &>/dev/null || [[ -d "$HOME/.local/share/fonts/FiraCode" ]]; then
    success "FiraCode Nerd Font already installed"
else
    info "Installing FiraCode Nerd Font..."
    sudo dnf copr enable -y atim/nerd-fonts
    sudo dnf install -y firacode-nerd-fonts
    success "FiraCode Nerd Font installed"
fi
install_extra brave-origin-beta   "Brave browser"      sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo
install_extra tailscale           "Tailscale"          sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
install_extra throttled           "ThinkPad throttle fix" sudo dnf copr enable -y abn/throttled
if rpm -q claude-code &>/dev/null; then
    success "Claude Code already installed"
else
    info "Installing Claude Code..."
    sudo tee /etc/yum.repos.d/claude-code.repo > /dev/null << 'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
    sudo dnf install -y claude-code
    success "Claude Code installed"
fi

# -----------------------------------------------------------------------------
# 4. LSP tools for micro
# -----------------------------------------------------------------------------
# Ensure npm installs to ~/.local so global installs never need root.
if ! grep -qF 'prefix=' "$HOME/.npmrc" 2>/dev/null; then
    info "Setting npm prefix to ~/.local..."
    npm config set prefix "$HOME/.local"
    success "npm prefix set"
fi

if npm list -g vscode-langservers-extracted &>/dev/null; then
    success "vscode-langservers-extracted already installed"
else
    info "Installing vscode-langservers-extracted for micro LSP..."
    npm install -g vscode-langservers-extracted
    success "LSP tools installed"
fi

# -----------------------------------------------------------------------------
# 5. Stow dotfiles
# -----------------------------------------------------------------------------
info "Stowing dotfiles..."

PACKAGES=(fish lf micro kitty sway swaylock waybar rofi yt-dlp fastfetch)

for pkg in "${PACKAGES[@]}"; do
    if [[ -d "$DOTFILES/$pkg" ]]; then
        stow -vt "$HOME" -d "$DOTFILES" "$pkg"
        success "Stowed $pkg"
    else
        warn "$pkg directory not found, skipping"
    fi
done

# -----------------------------------------------------------------------------
# 6. System services
# -----------------------------------------------------------------------------
info "Enabling system services..."

sudo systemctl enable --now tailscaled.service
sudo systemctl enable --now throttled.service
sudo systemctl enable --now sshd.service
sudo systemctl enable --now smartd.service
success "System services enabled"

# -----------------------------------------------------------------------------
# 7. Battery charge threshold
# -----------------------------------------------------------------------------
BATTERY_SERVICE="/etc/systemd/system/battery-charge-threshold.service"
if systemctl is-enabled battery-charge-threshold.service &>/dev/null; then
    success "Battery charge threshold service already enabled"
else
    info "Creating battery charge threshold service (85%)..."
    sudo tee "$BATTERY_SERVICE" > /dev/null << 'EOF'
[Unit]
Description=Set battery charge threshold
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo 85 > /sys/class/power_supply/BAT0/charge_control_end_threshold'

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl enable --now battery-charge-threshold.service
    success "Battery charge threshold service created and enabled"
fi

# -----------------------------------------------------------------------------
# 8. Default shell
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
# 9. Font cache
# -----------------------------------------------------------------------------
info "Rebuilding font cache..."
fc-cache -f
success "Font cache rebuilt"

# -----------------------------------------------------------------------------
# 10. XDG user directories
# -----------------------------------------------------------------------------
info "Creating XDG user directories..."
xdg-user-dirs-update
mkdir -p "$HOME/Pictures/Screenshots"
if ! grep -q 'XDG_SCREENSHOTS_DIR' "$HOME/.config/user-dirs.dirs"; then
    echo 'XDG_SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"' >> "$HOME/.config/user-dirs.dirs"
fi
success "XDG user directories created"

# -----------------------------------------------------------------------------
# 11. Home directory permissions for SDDM
# -----------------------------------------------------------------------------
# SDDM runs as its own user and needs execute permission on $HOME to traverse
# the path to wallpapers stored in ~/Pictures.
if [[ "$(stat -c '%a' "$HOME")" != "711" ]]; then
    info "Setting home directory permissions for SDDM wallpaper access..."
    chmod 711 "$HOME"
    success "Home directory set to 711"
else
    success "Home directory permissions already correct"
fi

# -----------------------------------------------------------------------------
# 12. Auto-login (SDDM)
# -----------------------------------------------------------------------------
# The Fedora Sway spin installer may already configure this; skip if so.
if grep -q "^User=$USER" /etc/sddm.conf 2>/dev/null || grep -rq "^User=$USER" /etc/sddm.conf.d/ 2>/dev/null; then
    success "SDDM auto-login already configured for $USER"
else
    info "Configuring SDDM auto-login for $USER..."
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null << EOF
[Autologin]
User=$USER
Session=sway
EOF
    success "SDDM auto-login configured"
fi

# -----------------------------------------------------------------------------
# 13. Passwordless keyring (gnome-keyring PAM unlock)
# -----------------------------------------------------------------------------
# With auto-login there is no PAM auth token to unlock the keyring, so add the
# gnome-keyring auth line — it will unlock using an empty password. The login
# keyring is removed so it is recreated fresh without a password; on a new
# install it will not exist yet so rm -f is a no-op.
if grep -q 'auth.*optional.*pam_gnome_keyring' /etc/pam.d/sddm-autologin 2>/dev/null; then
    success "gnome-keyring PAM auth already configured"
else
    info "Configuring silent keyring unlock for auto-login..."
    sudo sed -i '/auth.*pam_permit\.so/a auth       optional    pam_gnome_keyring.so' /etc/pam.d/sddm-autologin
    grep -q 'auth.*optional.*pam_gnome_keyring' /etc/pam.d/sddm-autologin \
        || warn "pam_permit.so anchor not found — gnome-keyring line was NOT inserted"
    rm -f "$HOME/.local/share/keyrings/login.keyring"
    success "gnome-keyring PAM auth configured"
fi

# -----------------------------------------------------------------------------
# 14. Suppress login message
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
printf '  3. Run: tailscale up --exit-node=<node>  (optional: route through homelab)\n'

printf '\n'
