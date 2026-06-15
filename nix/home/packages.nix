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
    bc
    tree
    rsync
    unzip
    zip

    # File management
    file          # MIME type detection (used by lf preview script)
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
    claude-code

    # System
    btop
    fastfetch
    transmission_4
    nvme-cli
    smartmontools

    # Networking
    firefox
    spotify

    # Wayland utilities
    wev           # introspect key events; useful for debugging keybindings

    # Theming
    adwaita-icon-theme
    gnome-themes-extra
    gtk3
  ];
}
