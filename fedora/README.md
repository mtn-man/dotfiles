# Fedora Sway Dotfiles

Setup for a fresh Fedora Sway spin install.

## Install

1. Connect to wifi:
   ```bash
   nmcli device wifi connect "SSID" password "yourpassword"
   ```

2. Clone the dotfiles:
   ```bash
   git clone https://github.com/mtn-man/dotfiles ~/.dotfiles
   ```

3. Run the bootstrap:
   ```bash
   ~/.dotfiles/fedora/fedora-bootstrap.sh
   ```

The bootstrap script is idempotent — re-run it anytime via the `update` fish function to install missing packages, upgrade the system, and re-apply configuration.
