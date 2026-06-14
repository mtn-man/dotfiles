{ config, pkgs, ... }:

# Rofi helper scripts and data files are managed as xdg.configFile entries so
# they land at the paths the scripts expect ($HOME/.config/rofi/...).

{
  programs.rofi = {
    enable  = true;
    package = pkgs.rofi;
    # Actual config lives in extraConfig + xdg.configFile (theme, scripts, data).
    extraConfig = {
      modes        = "combi,window";
      combi-modes  = "drun,actions:${config.xdg.configHome}/rofi/actions.sh,places:${config.xdg.configHome}/rofi/places.sh,bookmarks:${config.xdg.configHome}/rofi/bookmarks.sh";
      show-icons   = true;
      theme        = "${config.xdg.configHome}/rofi/dark-pastel.rasi";
    };
  };

  xdg.configFile = {
    "rofi/dark-pastel.rasi".source = ./rofi/dark-pastel.rasi;

    "rofi/actions.sh"    = { source = ./rofi/actions.sh;    executable = true; };
    "rofi/bookmarks.sh"  = { source = ./rofi/bookmarks.sh;  executable = true; };
    "rofi/places.sh"     = { source = ./rofi/places.sh;     executable = true; };

    "rofi/actions".source    = ./rofi/actions;
    "rofi/bookmarks".source  = ./rofi/bookmarks;
    "rofi/places".source     = ./rofi/places;
  };
}
