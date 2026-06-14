{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/hardware.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/sway.nix
  ];

  networking.hostName = "thinkpad";

  # Keep in sync with home.stateVersion in home/default.nix.
  # After the initial install this value should not be changed — it gates
  # backwards-compat shims, not which packages get installed.
  system.stateVersion = "25.05";
}
