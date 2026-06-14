{ pkgs, ... }:

{
  users.users.eli = {
    isNormalUser = true;
    description  = "Eli";
    extraGroups  = [ "wheel" "networkmanager" "video" "audio" "input" ];
    shell        = pkgs.fish;
  };

  security.sudo.wheelNeedsPassword = true;

  # Fish must be enabled at the system level to appear in /etc/shells,
  # which is required for it to be a valid login shell.
  programs.fish.enable = true;
}
