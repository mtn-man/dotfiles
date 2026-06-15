{ config, pkgs, ... }:

# WALLPAPER: copy the asset into place before first build:
#   cp fedora/sway/.config/sway/assets/wallhaven-yxyye7_3840x2400.png nix/assets/
# The file is referenced as a Nix store path so it must exist at build time.

let
  wallpaper = ../assets/wallhaven-yxyye7_3840x2400.png;
  mod       = "Mod4";
in {

  # Drop the helper scripts into ~/.config/sway/ so sway can exec them.
  xdg.configFile = {
    "sway/power-menu.sh" = { source = ./sway/power-menu.sh; executable = true; };
    "sway/trash-empty.sh" = { source = ./sway/trash-empty.sh; executable = true; };
  };

  wayland.windowManager.sway = {
    enable = true;

    config = {
      modifier  = mod;
      terminal  = "kitty";
      bars      = [];  # waybar runs independently

      fonts = {
        names = [ "FiraCode Nerd Font Mono" ];
        size  = 10.0;
      };

      gaps = {
        inner     = 0;
        smartGaps = true;
      };

      focus.followMouse = false;

      output = {
        "*"    = { bg = "${wallpaper} fill"; };
        "DP-2" = { adaptive_sync = "on"; };
      };

      input = {
        "1739:0:Synaptics_TM3471-020" = {
          natural_scroll = "enabled";
          tap            = "enabled";
          dwt            = "enabled";
          pointer_accel  = "0.3";
        };
        "1133:16500:Logitech_G305" = {
          pointer_accel = "-0.5";
        };
      };

      startup = [
        { command = "autotiling"; }
        # Import Wayland compositor vars so systemd user services can find the socket.
        { command = "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK"; always = true; }
        { command = "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK"; always = true; }
      ];

      window.commands = [
        { criteria = { app_id = "mpv"; };                         command = "inhibit_idle fullscreen"; }
        { criteria = { app_id = "org.jellyfin.JellyfinDesktop"; }; command = "inhibit_idle fullscreen"; }
        { criteria = { app_id = "firefox"; };                        command = "inhibit_idle fullscreen"; }
      ];

      # All keybindings are listed explicitly; this replaces the home-manager defaults.
      keybindings = {
        "${mod}+Return"     = "exec kitty";
        "${mod}+q"          = "kill";
        "${mod}+space"      = "exec pgrep -x rofi && pkill -x rofi || rofi -show combi";
        "${mod}+c"          = "exec firefox";
        "${mod}+Shift+c"    = "reload";
        "${mod}+Shift+t"    = "exec ${config.xdg.configHome}/sway/trash-empty.sh";
        "${mod}+Shift+n"    = "exec dunstctl set-paused toggle && pkill -SIGRTMIN+8 waybar";
        "${mod}+Escape"     = "exec ${config.xdg.configHome}/sway/power-menu.sh";

        "${mod}+p"          = "exec grimshot save output";
        "${mod}+Shift+p"    = "exec grimshot save active";
        "${mod}+Ctrl+p"     = "exec grimshot save area";

        # Focus — vim keys + arrows
        "${mod}+h"          = "focus left";
        "${mod}+j"          = "focus down";
        "${mod}+k"          = "focus up";
        "${mod}+l"          = "focus right";
        "${mod}+Left"       = "focus left";
        "${mod}+Down"       = "focus down";
        "${mod}+Up"         = "focus up";
        "${mod}+Right"      = "focus right";

        # Move
        "${mod}+Shift+h"    = "move left";
        "${mod}+Shift+j"    = "move down";
        "${mod}+Shift+k"    = "move up";
        "${mod}+Shift+l"    = "move right";
        "${mod}+Shift+Left" = "move left";
        "${mod}+Shift+Down" = "move down";
        "${mod}+Shift+Up"   = "move up";
        "${mod}+Shift+Right" = "move right";

        # Workspaces
        "${mod}+1"          = "workspace number 1";
        "${mod}+2"          = "workspace number 2";
        "${mod}+3"          = "workspace number 3";
        "${mod}+4"          = "workspace number 4";
        "${mod}+5"          = "workspace number 5";
        "${mod}+6"          = "workspace number 6";
        "${mod}+7"          = "workspace number 7";
        "${mod}+8"          = "workspace number 8";
        "${mod}+9"          = "workspace number 9";
        "${mod}+0"          = "workspace number 10";
        "${mod}+Shift+1"    = "move container to workspace number 1";
        "${mod}+Shift+2"    = "move container to workspace number 2";
        "${mod}+Shift+3"    = "move container to workspace number 3";
        "${mod}+Shift+4"    = "move container to workspace number 4";
        "${mod}+Shift+5"    = "move container to workspace number 5";
        "${mod}+Shift+6"    = "move container to workspace number 6";
        "${mod}+Shift+7"    = "move container to workspace number 7";
        "${mod}+Shift+8"    = "move container to workspace number 8";
        "${mod}+Shift+9"    = "move container to workspace number 9";
        "${mod}+Shift+0"    = "move container to workspace number 10";
        "${mod}+Ctrl+Left"  = "workspace prev";
        "${mod}+Ctrl+Right" = "workspace next";
        "${mod}+Ctrl+h"     = "workspace prev";
        "${mod}+Ctrl+l"     = "workspace next";

        # Layout
        "${mod}+b"          = "splith";
        "${mod}+v"          = "splitv";
        "${mod}+s"          = "layout stacking";
        "${mod}+w"          = "layout tabbed";
        "${mod}+e"          = "layout toggle split";
        "${mod}+f"          = "fullscreen";
        "${mod}+Shift+space" = "floating toggle";
        "${mod}+Tab"        = "exec rofi -show window";
        "${mod}+a"          = "focus parent";

        # Scratchpad
        "${mod}+Shift+minus" = "move scratchpad";
        "${mod}+minus"       = "scratchpad show";

        # Resize mode
        "${mod}+r"          = "mode resize";
      };

      modes = {
        resize = {
          h      = "resize shrink width 10px";
          j      = "resize grow height 10px";
          k      = "resize shrink height 10px";
          l      = "resize grow width 10px";
          Left   = "resize grow width 10px";
          Down   = "resize grow height 10px";
          Up     = "resize shrink height 10px";
          Right  = "resize shrink width 10px";
          Return = "mode default";
          Escape = "mode default";
        };
      };
    };

    # Options that don't have a structured Nix equivalent in the HM module
    extraConfig = ''
      # Function / media keys (--locked = active on the lock screen too)
      bindsym --locked XF86MonBrightnessUp   exec brightnessctl set 5%+
      bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-
      bindsym --locked XF86AudioRaiseVolume  exec pamixer -i 5
      bindsym --locked XF86AudioLowerVolume  exec pamixer -d 5
      bindsym --locked XF86AudioMute         exec pamixer -t
      bindsym --locked XF86AudioMicMute      exec pamixer --default-source -t
      bindsym          XF86AudioPlay         exec playerctl play-pause
      bindsym          XF86AudioNext         exec playerctl next
      bindsym          XF86AudioPrev         exec playerctl previous

      xwayland disable
      default_border none
      default_floating_border none
      focus_on_window_activation focus
      seat * hide_cursor 3000
      workspace_auto_back_and_forth yes
      floating_modifier ${mod} normal

      bindgesture swipe:3:right workspace prev
      bindgesture swipe:3:left  workspace next
      bindgesture swipe:4:right workspace prev
      bindgesture swipe:4:left  workspace next

      # Lid close/open — toggle internal display
      bindswitch --reload --locked lid:on  output eDP-1 disable
      bindswitch --reload --locked lid:off output eDP-1 enable
    '';
  };

  # Swayidle: power displays off after 5 min idle; no auto-lock.
  # Lock is triggered explicitly via the power menu (${mod}+Escape).
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout       = 300;
        command       = "${pkgs.sway}/bin/swaymsg \"output * power off\"";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
      }
    ];
  };
}
