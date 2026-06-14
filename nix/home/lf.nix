{ pkgs, ... }:

# pv.sh and clean.sh live in nix/home/lf/ as modified NixOS versions.
# The key change from Fedora: cache invalidation uses the Nix system profile
# path (/nix/var/nix/profiles/system) instead of the RPM database.

let
  pvScript = pkgs.writeTextFile {
    name       = "lf-pv";
    text       = builtins.readFile ./lf/pv.sh;
    executable = true;
  };
  cleanScript = pkgs.writeTextFile {
    name       = "lf-clean";
    text       = builtins.readFile ./lf/clean.sh;
    executable = true;
  };
in {
  programs.lf = {
    enable = true;

    settings = {
      sortby  = "time";
      reverse = true;
      icons   = true;
      shell   = "fish";
    };

    # Previewer/cleaner scripts are store paths so they're always executable.
    previewer.source = pvScript;
    cleaner          = cleanScript;

    keybindings = {
      o             = "&xdg-open \"$fx\"";
      "<enter>"     = "&xdg-open \"$fx\"";
      "."           = "set hidden!";
      d             = "$trash \"$fx\"";
      "<backspace2>" = "$trash \"$fx\"";
      S             = "shell";
      R             = "reload";
      e             = "$micro \"$fx\"";
      c             = "copy";
      v             = "paste";
      "<esc>"       = "quit";
      D             = "delete";
      H             = "cd ~";
      x             = "cut";
      C             = "clear";
      z             = "z";
    };

    # zoxide integration: teach lf about visited dirs and expose the z command.
    extraConfig = ''
      cmd cd ''${{
          command cd -- $argv
          if type -q zoxide
              zoxide add -- $PWD >/dev/null 2>&1
          end
      }}

      cmd z ''${{
          if not type -q zoxide
              exit 0
          end

          set -l dir

          if test (count $argv) -gt 0
              set dir (zoxide query -- $argv)
          else
              set dir (zoxide query -i)
          end

          if test -n "$dir"
              set -l q (string replace -a "'" "'\\'''" -- "$dir")
              lf -remote "send $id cd '$q'"
          end
      }}

      set hidden!
    '';
  };

  # Icon definitions (Nerd Fonts v3) — copied from fedora/lf/.config/lf/icons
  xdg.configFile."lf/icons".source = ./lf/icons;
}
