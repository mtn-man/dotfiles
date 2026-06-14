{ ... }:

{
  imports = [
    ./packages.nix
    ./fish.nix
    ./sway.nix
    ./waybar.nix
    ./kitty.nix
    ./rofi.nix
    ./swaylock.nix
    ./lf.nix
    ./micro.nix
  ];

  home.username     = "eli";
  home.homeDirectory = "/home/eli";

  xdg.enable                       = true;
  xdg.userDirs.enable              = true;
  xdg.userDirs.setSessionVariables = true;

  # dunst is provided automatically by the Fedora Sway spin; on NixOS we start
  # it explicitly as a systemd user service.
  services.dunst.enable = true;

  # home-manager manages itself; lets you run `home-manager switch` directly.
  programs.home-manager.enable = true;

  # Keep in sync with system.stateVersion in hosts/thinkpad/default.nix.
  home.stateVersion = "25.05";
}
