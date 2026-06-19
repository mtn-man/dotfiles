{ ... }:

{
  # zoxide init is handled by programs.zoxide below; do not add it to shellInit.
  programs.zoxide = {
    enable                = true;
    enableFishIntegration = true;
    options               = [ "--cmd" "cd" ];  # replaces cd with zoxide's smart jump
  };

  programs.fish = {
    enable = true;

    shellInit = ''
      set -gx EDITOR "micro"
      set -g  HOMELAB       "100.106.45.25"
      set -g  HOMELAB_LOCAL "192.168.0.43"
      set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

      fish_add_path -gP ~/.local/bin
      fish_add_path -gP ~/.cargo/bin
      fish_add_path -gP ~/go/bin
    '';

    shellAliases = {
      ".."     = "cd ..";
      "...."   = "cd ../..";
      "......" = "cd ../../..";
    };

    shellAbbrs = {
      a      = "after";
      a_num  = { regex = "^a([1-9][0-9]*)$"; function = "__abbr_timer_minutes"; };
      u      = "update";
      ff     = "fastfetch";
      lg     = "lazygit";
      m      = "micro";
      gs     = "git status";
      l      = "eza --git --group-directories-first";
      src    = "source $__fish_config_dir/config.fish";
      ts     = "tailscale";
      mm     = "mintmedia";
      caf    = "caffeinate";
      portal = "curl -v http://neverssl.com 2>&1 | grep -i location";
    };

    functions = {

      __abbr_timer_minutes = {
        argumentNames = "token";
        body = ''
          set -l minutes (string match -r --groups-only '^a([1-9][0-9]*)$' -- $token)
          or return 1
          printf 'after %sm\n' "$minutes"
        '';
      };

      fish_greeting = { body = ""; };

      fish_prompt = {
        description = "Write out the prompt";
        body = ''
          set -l last_pipestatus $pipestatus

          if not set -q __prompt_git_cfg_done
              set -g __prompt_git_cfg_done 1
              set -g __fish_git_prompt_showdirtystate 1
              set -g __fish_git_prompt_showuntrackedfiles 1
              set -g __fish_git_prompt_showupstream auto
              set -g __fish_git_prompt_color_branch yellow
              set -g __fish_git_prompt_char_dirtystate '✚'
              set -g __fish_git_prompt_char_stagedstate '●'
              set -g __fish_git_prompt_char_untrackedfiles '…'
              set -g __fish_git_prompt_char_upstream_ahead '↑'
              set -g __fish_git_prompt_char_upstream_behind '↓'
          end

          set -l color_cwd
          set -l suffix
          if functions -q fish_is_root_user; and fish_is_root_user
              set color_cwd (set -q fish_color_cwd_root; and echo $fish_color_cwd_root; or echo $fish_color_cwd)
              set suffix '#'
          else
              set color_cwd $fish_color_cwd
              set suffix '➤'
          end

          set_color $color_cwd
          echo -n (prompt_pwd)
          set_color normal

          # Cache fish_vcs_prompt for 3 seconds; invalidate on branch change.
          set -l now (date +%s)
          set -l cache_stale 1
          if set -q __git_prompt_cache_pwd __git_prompt_cache_time __git_prompt_cache_gitdir
              and test "$__git_prompt_cache_pwd" = "$PWD"
              and test (math "$now - $__git_prompt_cache_time") -lt 3
              set -l head_now ""
              test -n "$__git_prompt_cache_gitdir"
                  and read head_now < "$__git_prompt_cache_gitdir/HEAD" 2>/dev/null
              test "$head_now" = "$__git_prompt_cache_head"
              and set cache_stale 0
          end

          set -l vcs_str
          if test $cache_stale -eq 1
              set vcs_str (fish_vcs_prompt)
              set -g __git_prompt_cache_pwd     $PWD
              set -g __git_prompt_cache_time    $now
              set -g __git_prompt_cache_val     $vcs_str
              set -g __git_prompt_cache_gitdir  (git rev-parse --git-dir 2>/dev/null)
              set -g __git_prompt_cache_head    ""
              test -n "$__git_prompt_cache_gitdir"
                  and read -g __git_prompt_cache_head < "$__git_prompt_cache_gitdir/HEAD" 2>/dev/null
          else
              set vcs_str $__git_prompt_cache_val
          end

          printf '%s ' $vcs_str

          set -l status_color  (set_color $fish_color_status)
          set -l statusb_color (set_color --bold $fish_color_status)
          set -l prompt_status (__fish_print_pipestatus "[" "]" "|" \
              "$status_color" "$statusb_color" $last_pipestatus)
          echo -n $prompt_status
          set_color normal
          echo -n "$suffix "
        '';
      };

      fish_right_prompt = {
        body = ''
          if not set -q CMD_DURATION; or test $CMD_DURATION -le 3000
              return
          end
          set -l secs (math "$CMD_DURATION / 1000")
          set_color brblack
          echo -n "$secs"s
          set_color normal
        '';
      };

      batt = {
        description = "Show battery details via upower";
        body = ''
          upower -i (upower -e | grep BAT) | grep -v "History\|^\s*[0-9]"
        '';
      };

      update = {
        description = "Rebuild the NixOS system from the flake";
        body = ''
          set -l flake "$HOME/.dotfiles/nix"
          sudo nixos-rebuild switch --flake "$flake#thinkpad"; or return 1
          echo (set_color normal --bold)"rebuild complete"(set_color normal)
        '';
      };

      caffeinate = {
        description = "Prevent idle/sleep via systemd-inhibit";
        body = ''
          if not command -q systemd-inhibit
              echo "caffeinate: systemd-inhibit not found" >&2
              return 127
          end
          systemd-inhibit --what=idle --who=fish --why=caffeinate sleep infinity
        '';
      };

      mkcd = {
        description = "Create directory and cd into it";
        body = "mkdir -p $argv; and cd $argv";
      };

      lp = {
        description = "List PATH entries with existence check";
        body = ''
          for dir in $PATH
              if test -d $dir
                  echo $dir
              else
                  set_color red; echo "$dir (missing)"; set_color normal
              end
          end
        '';
      };

      gr = {
        description = "Jump to a git repo root via fzf";
        body = ''
          set -l roots ~/dev
          set -l tab (printf '\t')

          for tool in git eza fzf fd
              if not command -q $tool
                  echo "gr: $tool not found" >&2; return 127
              end
          end

          set -l dirs (fd -L -H -t d '^\.git$' $roots 2>/dev/null \
              | string replace '/.git' "" | sort)

          if test (count $dirs) -eq 0
              echo "gr: no git repos found under: $roots" >&2; return 1
          end

          set -l menu
          for d in $dirs
              set menu $menu (string join "$tab" (path basename $d) "$d")
          end

          set -l choice (
              printf '%s\n' $menu | fzf \
                  --prompt='gr> ' \
                  --height=80% \
                  --reverse \
                  --delimiter="$tab" \
                  --with-nth=1
          )

          if test -z "$choice"
              echo "gr: cancelled" >&2; return 1
          end

          set -l target (string split "$tab" -- $choice)[2]

          if test -d "$target"
              cd "$target"
              eza -aTL4 --git-ignore
              zoxide add "$target"
          else
              echo "gr: target no longer exists: $target" >&2; return 1
          end
        '';
      };

      fm = {
        description = "Open file in micro via fd search (fzf when multiple matches)";
        body = ''
          for tool in fd fzf micro bat
              if not command -q $tool
                  echo "fm: required tool missing: $tool" >&2; return 1
              end
          end

          if test (count $argv) -ne 1
              echo "fm: usage — fm <filename>" >&2; return 1
          end

          set -l fd_opts --no-ignore -L -H -t f --exclude .git
          set -l matches (fd $fd_opts "$argv[1]" ~/dev)

          if test (count $matches) -eq 0
              echo "fm: no matches in ~/dev, searching cwd..."
              set matches (fd $fd_opts "$argv[1]" .)
          end

          switch (count $matches)
              case 0
                  echo "fm: no matches found"; return 1
              case 1
                  micro $matches
              case '*'
                  set -l chosen (printf '%s\n' $matches | fzf -i \
                      --prompt='fm> ' \
                      --preview='bat --color=always --style=plain --theme="ansi" {}' \
                      --preview-window='right:60%:wrap')
                  if test -z "$chosen"
                      echo "fm: cancelled"; return 1
                  end
                  micro $chosen
          end
        '';
      };

      gcp = {
        description = "Review changes, stage all, commit (message or editor), push";
        body = ''
          git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
              echo "gcp: not inside a git repository" >&2; return 1
          end

          echo (set_color yellow)"==> Pending Changes (git status -sb):"(set_color normal)
          git status -sb
          echo
          echo (set_color yellow)"==> Impact Analysis (git diff --stat):"(set_color normal)
          git diff --stat

          set -l untracked (git ls-files --others --exclude-standard)
          if set -q untracked[1]
              echo
              echo (set_color yellow)"==> Untracked Files (will be added):"(set_color normal)
              printf '%s\n' $untracked
          end

          if status is-interactive
              echo
              read -n 1 -P "Proceed with stage, commit, and push? [Y/n] " confirm
              echo
              if string match -qr '^[Nn]$' -- "$confirm"
                  echo "gcp: aborted" >&2; return 1
              end
          end

          git add -A; or return 1

          if git diff --cached --quiet
              echo "gcp: nothing staged to commit"; return
          end

          if test (count $argv) -gt 0
              git commit -m (string join " " -- "$argv"); or return 1
          else
              git commit; or return 1
          end

          git push; or return 1
        '';
      };

      lf = {
        description = "lf with quit-and-cd integration";
        body = ''
          set -l tmp (mktemp)
          set -lx LF_PREVIEW_CACHE_DIR "$HOME/.cache/lf"

          if test -z "$tmp"
              set tmp "/tmp/lf-last-dir-$fish_pid"
              command touch "$tmp" 2>/dev/null
          end

          command mkdir -p "$LF_PREVIEW_CACHE_DIR/thumbs" 2>/dev/null

          find "$LF_PREVIEW_CACHE_DIR/thumbs" -maxdepth 1 -name "*.jpg"   -mtime +30 -delete 2>/dev/null
          find "$LF_PREVIEW_CACHE_DIR/thumbs" -maxdepth 1 -name "*.tmp.*" -mtime +1  -delete 2>/dev/null

          command lf -last-dir-path="$tmp" $argv
          set -l lf_status $status

          if test -f "$tmp"
              read -l dir < "$tmp"
              if test -n "$dir"; and test -d "$dir"; and test "$dir" != (pwd)
                  cd -- "$dir"
              end
          end

          rm -f "$tmp"
          return $lf_status
        '';
      };

      stow-add = {
        description = "Redirect stow-add to home-manager workflow";
        body = ''
          echo "stow-add: NixOS manages configs declaratively via home-manager." >&2
          echo "stow-add: Add your config to nix/home/ instead of stowing it." >&2
          if test (count $argv) -eq 1
              echo "stow-add: existing config for reference: ~/.config/$argv[1]" >&2
          end
          return 1
        '';
      };

      __paste = {
        body = "wl-paste 2>/dev/null | string trim";
      };

      tm = {
        description = "Send magnet links and torrents to homelab Transmission";
        body = ''
          set -l host "$HOMELAB:9091"

          if not command -q transmission-remote
              echo "tm: transmission-remote not found" >&2; return 127
          end

          if test "$argv[1]" = ping
              transmission-remote "$host" -st; return
          end

          if not transmission-remote "$host" -l >/dev/null 2>&1
              echo "tm: Transmission RPC not reachable at $host" >&2
              echo "tm: ensure tailscale is active and homelab is up." >&2
              return 1
          end

          set -l input
          if set -q argv[1]
              set input (string trim -- "$argv[1]")
          else
              set input (__paste)
          end

          if test -z "$input"
              echo "tm: clipboard is empty" >&2; return 1
          end

          if string match -q "*.torrent" -- "$input"
              if not test -f "$input"
                  echo "tm: file not found: $input" >&2; return 1
              end
              transmission-remote "$host" -a "$input"
              and echo "tm: torrent added — http://$host/transmission/web/"
              return
          end

          if not string match -rq '^magnet:\?' -- "$input"
              echo "tm: not a magnet link or .torrent file" >&2; return 1
          end
          if not string match -rq 'xt=urn:btih:' -- "$input"
              echo "tm: magnet missing xt=urn:btih:" >&2; return 1
          end

          transmission-remote "$host" -a "$input"
          and echo "tm: magnet added — http://$host/transmission/web/"
        '';
      };

      __snap_file = {
        argumentNames = ["label" "path" "lang"];
        body = ''
          echo "### $label"
          echo
          if test -f $path
              if test -n "$lang"
                  echo '```'"$lang"
                  cat $path
                  echo
                  echo '```'
              else
                  cat $path
              end
          else
              echo "(file not found: $path)"
              set -ga __snap_errors $path
          end
          echo
          echo "---"
          echo
        '';
      };

      snap = {
        description = "Rebuild ~/dev/snapshot.md with live system data";
        body = ''
          set -l outfile ~/dev/snapshot.md
          set -l d ~/.dotfiles/nix
          set -g __snap_errors

          if not command -q fastfetch
              echo "snap: fastfetch not found" >&2
              return 127
          end

          begin
              # System info
              echo '```'
              fastfetch --logo none \
                  | string replace -ra '\x1b\[[0-9;]*[A-Za-z]' "" \
                  | string match -rv '█'
              echo '```'

              echo
              echo "## Battery"
              echo '```'
              set -l bat_path (upower -e 2>/dev/null | grep -i battery | head -1)
              if test -n "$bat_path"
                  upower -i $bat_path | grep -E "state|percentage|energy-full|capacity|time to|cycle" | string trim
              else
                  echo "(no battery found)"
              end
              echo '```'

              echo
              echo "## Memory"
              echo '```'
              free -h
              echo '```'

              echo
              echo "System note: NixOS (unstable) on ThinkPad T14 Gen 1 (i5-10210U, 16GB RAM)."
              echo "Config managed as a Nix flake at ~/.dotfiles/nix/."
              echo "Home environment managed by home-manager as a NixOS module."
              echo "Tailscale is the only VPN on this machine."
              echo "Notification daemon is dunst; idle/lock is swayidle."
              echo

              echo "## Flake inputs"
              echo '```'
              nix flake metadata "$d" 2>/dev/null \
                  | string replace -ra '\x1b\[[0-9;]*[A-Za-z]' ""; or echo "(flake metadata unavailable)"
              echo '```'

              echo
              echo "## NixOS generation"
              echo '```'
              nixos-rebuild list-generations 2>/dev/null | tail -5; or echo "(unavailable)"
              echo '```'
              echo

              # Nix config — read directly from dotfiles repo
              __snap_file "flake.nix"                      $d/flake.nix                      nix
              __snap_file "hosts/thinkpad/default.nix"     $d/hosts/thinkpad/default.nix     nix
              __snap_file "modules/nixos/base.nix"         $d/modules/nixos/base.nix         nix
              __snap_file "modules/nixos/hardware.nix"     $d/modules/nixos/hardware.nix     nix
              __snap_file "modules/nixos/networking.nix"   $d/modules/nixos/networking.nix   nix
              __snap_file "modules/nixos/users.nix"        $d/modules/nixos/users.nix        nix
              __snap_file "modules/nixos/sway.nix"         $d/modules/nixos/sway.nix         nix
              __snap_file "home/default.nix"               $d/home/default.nix               nix
              __snap_file "home/packages.nix"              $d/home/packages.nix              nix
              __snap_file "home/fish.nix"                  $d/home/fish.nix                  nix
              __snap_file "home/sway.nix"                  $d/home/sway.nix                  nix
              __snap_file "home/sway/power-menu.sh"        $d/home/sway/power-menu.sh        bash
              __snap_file "home/sway/trash-empty.sh"       $d/home/sway/trash-empty.sh       bash
              __snap_file "home/waybar.nix"                $d/home/waybar.nix                nix
              __snap_file "home/kitty.nix"                 $d/home/kitty.nix                 nix
              __snap_file "home/rofi.nix"                  $d/home/rofi.nix                  nix
              __snap_file "home/rofi/dark-pastel.rasi"     $d/home/rofi/dark-pastel.rasi     text
              __snap_file "home/rofi/actions"              $d/home/rofi/actions              text
              __snap_file "home/rofi/actions.sh"           $d/home/rofi/actions.sh           bash
              __snap_file "home/rofi/bookmarks"            $d/home/rofi/bookmarks            text
              __snap_file "home/rofi/bookmarks.sh"         $d/home/rofi/bookmarks.sh         bash
              __snap_file "home/rofi/places"               $d/home/rofi/places               text
              __snap_file "home/rofi/places.sh"            $d/home/rofi/places.sh            bash
              __snap_file "home/swaylock.nix"              $d/home/swaylock.nix              nix
              __snap_file "home/lf.nix"                    $d/home/lf.nix                    nix
              __snap_file "home/lf/pv.sh"                  $d/home/lf/pv.sh                  bash
              __snap_file "home/lf/clean.sh"               $d/home/lf/clean.sh               bash
              __snap_file "home/micro.nix"                 $d/home/micro.nix                 nix
              __snap_file "home/kanshi.nix"                $d/home/kanshi.nix                nix

          end > $outfile

          echo "snap: updated $outfile"

          if set -q __snap_errors[1]
              echo "snap: missing files:"
              for p in $__snap_errors
                  echo "  $p"
              end
          end
          set -e __snap_errors
        '';
      };

      yt = {
        description = "Download YouTube videos with options";
        body = ''
          set -l min_h 720
          set -l max_h 1080
          set -l codec_pref avc1

          if not command -q yt-dlp
              echo "yt: yt-dlp not found" >&2; return 127
          end

          argparse -n yt 'h/help' 'o/open' 'i/interactive' -- $argv; or return 1

          if set -q _flag_help
              echo "Usage: yt [OPTIONS] [URL]"
              echo "  -o, --open         Open after download"
              echo "  -i, --interactive  Choose resolution and codec"
              echo "  -h, --help         This help"
              echo "If no URL provided, reads from clipboard."
              return
          end

          set -l url
          if set -q argv[1]
              set url (string trim -- $argv[1])
          else
              set url (__paste)
          end

          if test -z "$url"
              echo "yt: no URL and clipboard is empty" >&2; return 1
          end

          set -l outdir "$HOME/Videos/YouTube"
          mkdir -p "$outdir"; or return 1

          if set -q _flag_interactive
              echo "Select Max Resolution: [1] 720p  [2] 1080p (Default)  [3] 1440p  [4] 4K"
              read -n 1 -P "Choice > " res_choice; echo
              switch $res_choice
                  case 1; set max_h 720
                  case 3; set max_h 1440
                  case 4; set max_h 2160
                  case '*'; set max_h 1080
              end
              echo
              echo "Select Codec: [1] VP9  [2] AV1  [3] H.264 (Default)"
              read -n 1 -P "Choice > " codec_choice; echo
              switch $codec_choice
                  case 1; set codec_pref vp9
                  case 2; set codec_pref av01
                  case '*'; set codec_pref avc1
              end
              echo "Downloading: "$max_h"p / $codec_pref / MP4"; echo
          end

          set -l format_sel \
              "bestvideo[height<=$max_h][height>=$min_h][vcodec^=$codec_pref]+bestaudio/"\
              "bestvideo[height<=$max_h][height>=$min_h]+bestaudio/"\
              "best[height<=$max_h][height>=$min_h]/"\
              "bestvideo[height<=$max_h][vcodec^=$codec_pref]+bestaudio/"\
              "bestvideo[height<=$max_h]+bestaudio/"\
              "best[height<=$max_h]"

          set -l cmd yt-dlp \
              -f "$format_sel" \
              -S "res,fps" \
              --merge-output-format mp4 \
              --embed-thumbnail \
              --embed-metadata \
              --download-archive "$outdir/.yt-archive.txt" \
              --concurrent-fragments 5 \
              --buffer-size 1M \
              -o "%(title)s.%(ext)s" \
              --paths "$outdir" \
              --cookies-from-browser firefox \
              --no-overwrites

          set -q _flag_open; and set cmd $cmd --exec 'xdg-open {}'

          $cmd -- "$url"; or begin
              echo "yt: download failed" >&2; return 1
          end

          if status is-interactive; and command -q paplay
              paplay /run/current-system/sw/share/sounds/freedesktop/stereo/complete.oga &
          end

          set -q _flag_open
          and echo "✓ Downloaded and opened"
          or  echo "✓ Downloaded to: $outdir"
        '';
      };

    };
  };
}
