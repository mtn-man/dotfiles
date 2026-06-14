{ pkgs, ... }:

{
  # programs.sway.enable does more than install sway — it sets up the PAM
  # session, enables polkit, configures the D-Bus environment, and adds
  # necessary capabilities for screen locking and brightness control.
  programs.sway = {
    enable             = true;
    wrapperFeatures.gtk = true;   # fixes GTK theming inside sway
    extraPackages = with pkgs; [
      swaylock
      swayidle
      swaybg
      waybar
      rofi
      dunst
      libnotify
      wl-clipboard
      grim
      slurp
      sway-contrib.grimshot  # sway screenshot helper wrapping grim+slurp
      brightnessctl
      playerctl
      pamixer
      autotiling
      xdg-utils
      pavucontrol
      trash-cli          # provides trash-empty for trash-empty.sh
      networkmanagerapplet  # provides nm-connection-editor for waybar network on-click
    ];
  };

  security.polkit.enable = true;

  # PAM rule lets swaylock authenticate against system passwords.
  security.pam.services.swaylock = {};

  # xdg-desktop-portal-wlr provides screensharing and screenshots under Wayland.
  xdg.portal = {
    enable        = true;
    wlr.enable    = true;
    extraPortals  = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  services.displayManager.sddm = {
    enable          = true;
    wayland.enable  = true;
  };
  services.displayManager.autoLogin = {
    enable = true;
    user   = "eli";
  };

  # gnome-keyring stores SSH/GPG keys and browser credentials.
  services.gnome.gnome-keyring.enable            = true;
  security.pam.services.sddm.enableGnomeKeyring  = true;

  # Hint Electron/Chromium apps to use native Wayland rendering.
  environment.sessionVariables = {
    NIXOS_OZONE_WL     = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE   = "wayland";
    XDG_CURRENT_DESKTOP = "sway";
  };
}
