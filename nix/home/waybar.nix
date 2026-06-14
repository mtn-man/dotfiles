{ ... }:

# NOTE: the power-profiles-daemon waybar module is kept here for reference but
# will show nothing because TLP is used instead (PPD is disabled in hardware.nix).
# Remove or replace it with a custom TLP indicator if desired.

{
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        height  = 32;
        spacing = 0;

        modules-left   = [ "sway/workspaces" "sway/mode" "sway/scratchpad" ];
        modules-center = [ "sway/window" ];
        modules-right  = [
          "tray"
          "pulseaudio"
          "cpu"
          "memory"
          "battery"
          "custom/dunst"
          "network"
          "clock"
        ];

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs    = true;
        };
        "sway/mode"       = { format = "{}"; };
        "sway/scratchpad" = {
          format       = "{count}";
          show-empty   = false;
          tooltip      = true;
          tooltip-format = "{app}: {title}";
        };
        "sway/window" = { max-length = 80; };

        # Signal 8 lets sway's ${mod}+Shift+n instantly refresh this module.
        "custom/dunst" = {
          exec = ''dunstctl is-paused | grep -q true && echo '{"text":"󰂠","class":"paused","tooltip":"Notifications paused"}' || echo '{"text":"󰂞","class":"","tooltip":"Notifications active"}'  '';
          return-type = "json";
          interval    = 3600;
          signal      = 8;
          on-click    = "dunstctl set-paused toggle && pkill -SIGRTMIN+8 waybar";
        };

        pulseaudio = {
          format        = "{icon} {volume}%";
          format-muted  = "󰝟";
          format-icons  = { default = [ "󰕿" "󰖀" "󰕾" ]; };
          on-click      = "pavucontrol";
          tooltip       = false;
        };

        memory = {
          format         = "󰍛 {used:0.1f}G";
          tooltip-format = "{avail:0.1f}G available";
          interval       = 5;
          on-click       = "kitty btop";
        };

        cpu = {
          format   = "󰘚 {usage}%";
          tooltip  = false;
          interval = 5;
          on-click = "kitty btop";
        };

        battery = {
          states         = { warning = 30; critical = 15; };
          format         = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged  = "󰚥 {capacity}%";
          format-icons    = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip-format  = "{timeTo}\n{power:.1f}W";
          on-click        = "kitty --hold fish -c batt";
        };

        network = {
          format-wifi        = "{icon}";
          format-ethernet    = "󰈀";
          format-linked      = "󰈀";
          format-disconnected = "󰤭";
          format-icons       = [ "󰤟" "󰤢" "󰤥" "󰤨" ];
          tooltip-format-wifi = "{essid}  {signalStrength}%\n{ipaddr}/{cidr}";
          tooltip-format-ethernet = "{ifname}\n{ipaddr}/{cidr}";
          tooltip-format-disconnected = "Disconnected";
          on-click           = "nm-connection-editor";
        };

        clock = {
          format  = "{:%a %B %e %H:%M}";
          tooltip = false;
          interval = 60;
        };

        tray = { spacing = 8; };
      };
    };

    style = ''
      * {
          font-family: 'FiraCode Nerd Font Mono', monospace;
          font-size: 14px;
          min-height: 0;
          border: none;
          border-radius: 0;
      }

      window#waybar {
          background-color: rgba(0, 0, 0, 0.92);
          border-bottom: 1px solid rgba(150, 203, 254, 0.12);
          color: #FFFFFF;
      }

      #workspaces { margin: 0 4px; }

      #workspaces button {
          padding: 0 8px;
          background-color: transparent;
          color: #FFFFFF;
          opacity: 0.6;
          box-shadow: none;
      }
      #workspaces button:hover {
          background-color: rgba(255, 255, 255, 0.05);
          opacity: 0.85;
          box-shadow: none;
      }
      #workspaces button.focused,
      #workspaces button.active {
          color: #96CBFE;
          opacity: 1;
          background-color: rgba(150, 203, 254, 0.08);
          box-shadow: inset 0 2px #96CBFE;
      }
      #workspaces button.urgent {
          color: #FF6C60;
          opacity: 1;
      }

      #clock, #battery, #cpu, #pulseaudio, #memory,
      #custom-dunst, #scratchpad, #power-profiles-daemon, #tray, #mode {
          padding: 0 12px;
          color: #FFFFFF;
      }
      #network {
          padding: 0 12px;
          color: #FFFFFF;
          font-size: 16px;
      }
      #window {
          padding: 0 8px;
          color: #FFFFFF;
          opacity: 0.65;
      }

      #mode { color: #FFFFB6; box-shadow: inset 0 -2px #FFFFB6; }

      #custom-dunst.paused { color: #FF6C60; }

      #pulseaudio.muted { color: #555753; }

      #battery.charging, #battery.plugged { color: #A8FF60; }
      #battery.warning:not(.charging)     { color: #FFFFB6; }
      #battery.critical:not(.charging) {
          color: #FF6C60;
          animation-name: blink;
          animation-duration: 1s;
          animation-timing-function: steps(1);
          animation-iteration-count: infinite;
      }
      @keyframes blink { 50% { opacity: 0.4; } }

#tray > .passive       { -gtk-icon-effect: dim; }
      #tray > .needs-attention { -gtk-icon-effect: highlight; }
    '';
  };
}
