{ config, ... }:

# Wallpaper path must resolve at build time — see the note in sway.nix.

{
  programs.swaylock = {
    enable = true;
    settings = {
      image = "${config.xdg.configHome}/sway/assets/wallhaven-yxyye7_3840x2400.png";
      color = "1c1c1cff";

      font      = "FiraCode Nerd Font Mono";
      font-size = 16;

      indicator-radius    = 60;
      indicator-thickness = 8;

      # Hide separator lines
      line-color       = "00000000";
      line-clear-color = "00000000";
      line-ver-color   = "00000000";
      line-wrong-color = "00000000";
      separator-color  = "00000000";

      # Inside of the indicator (semi-transparent dark)
      inside-color       = "1c1c1c99";
      inside-clear-color = "1c1c1c99";
      inside-ver-color   = "1c1c1c99";
      inside-wrong-color = "1c1c1c99";

      # Ring — Dark Pastel palette
      ring-color       = "96cbfeff";  # blue  — idle
      ring-clear-color = "a8ff60ff";  # green — cleared
      ring-ver-color   = "ffffb6ff";  # yellow — verifying
      ring-wrong-color = "ff6c60ff";  # red   — wrong

      key-hl-color = "96cbfeff";
      bs-hl-color  = "ff6c60ff";

      text-color       = "dededeff";
      text-clear-color = "dededeff";
      text-ver-color   = "dededeff";
      text-wrong-color = "ff6c60ff";

      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };

  # Place the wallpaper asset where swaylock and sway both expect it.
  # The source path must exist in nix/assets/ before building.
  xdg.configFile."sway/assets/wallhaven-yxyye7_3840x2400.png".source =
    ../assets/wallhaven-yxyye7_3840x2400.png;
}
