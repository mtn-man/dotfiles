{ ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "FiraCode Nerd Font Mono";
      size = 12;
    };

    settings = {
      window_padding_width       = 8;
      background_opacity         = "0.8";
      confirm_os_window_close    = 0;
      wayland_titlebar_color     = "background";

      cursor_shape               = "underline";
      cursor_underline_thickness = 2;
      cursor_blink_interval      = 0;

      shell                      = "fish";
      shell_integration          = "no-cursor";

      scrollback_lines           = 10000;
      copy_on_select             = "yes";
      strip_trailing_spaces      = "smart";
      enable_audio_bell          = "no";
      mouse_hide_wait            = "3.0";

      tab_bar_style              = "hidden";

      # Dark Pastel palette
      background           = "#1C1C1C";
      foreground           = "#DEDEDE";
      selection_background = "#DEDEDE";
      selection_foreground = "#1C1C1C";
      cursor               = "#F8F8F8";

      color0  = "#1C1C1C";  # Black
      color8  = "#555753";
      color1  = "#FF6C60";  # Red
      color9  = "#FF6C60";
      color2  = "#A8FF60";  # Green
      color10 = "#A8FF60";
      color3  = "#FFFFB6";  # Yellow
      color11 = "#FFFFB6";
      color4  = "#96CBFE";  # Blue
      color12 = "#96CBFE";
      color5  = "#FF73FE";  # Magenta
      color13 = "#FF73FE";
      color6  = "#C6C5FE";  # Cyan
      color14 = "#C6C5FE";
      color7  = "#EEEEEE";  # White
      color15 = "#EEEEEE";
    };
  };
}
