{ ... }:

# Two display profiles:
#   undocked — built-in panel only
#   docked   — lid closed, external 1440p/144Hz only (built-in disabled)
#
# The external display is matched with * (wildcard) because its make/model/serial
# isn't known without being docked. After the first docked rebuild, run:
#   kanshi -d
# to see the exact description string and replace * with it for robustness.

{
  services.kanshi = {
    enable = true;

    profiles = {
      undocked = {
        outputs = [{
          criteria = "BOE 0x07C9";
          status   = "enable";
          mode     = "1920x1080@60.000";
          position = "0,0";
        }];
      };

      docked = {
        outputs = [
          {
            criteria = "BOE 0x07C9";
            status   = "disable";
          }
          {
            criteria = "*";
            status   = "enable";
            mode     = "2560x1440@144.000";
            position = "0,0";
          }
        ];
      };
    };
  };
}
