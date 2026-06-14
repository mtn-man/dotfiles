{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Shell utilities
    fd
    ripgrep
    fzf
    bat
    eza
    jq
    yq
    tealdeer      # tldr pages

    # File management
    lf
    unar
    ffmpeg        # video processing (lf preview, yt-dlp post-processing)
    ffmpegthumbnailer

    # Media
    yt-dlp
    mpv
    imv

    # Development
    lazygit
    gh
    micro
    go
    gopls

    # System
    btop
    fastfetch
    transmission_4
    kanshi        # automatic display configuration (output profiles when docked)
    nvme-cli
    smartmontools

    # Networking
    firefox

    # Wayland utilities
    wev           # introspect key events; useful for debugging keybindings

    # Theming
    adwaita-icon-theme
    gnome-themes-extra
    gtk3
  ];
}
