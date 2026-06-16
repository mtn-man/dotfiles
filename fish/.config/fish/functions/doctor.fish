function doctor --description 'Report system status and verify connectivity'
    set -l ok 1

    # Env var checks
    for var in HOMELAB HOMELAB_LOCAL MEDIA_SHARE
        if not set -q $var
            printf '%serror: $%s is not set%s\n' (set_color red) $var (set_color normal) >&2
            set ok 0
        end
    end

    # Toolchain checks
    # Required by doctor: jq (tailscale JSON parsing)
    # System toolchain (used by other functions): fd, rg, fzf, bat, eza
    set -l doctor_tools_ok 1
    for tool in jq
        if not command -q $tool
            printf '%s%s missing: proceeding in degraded state%s\n' (set_color red) $tool (set_color normal) >&2
            set ok 0
            set doctor_tools_ok 0
        end
    end
    set -l system_tools_ok 1
    for tool in fd rg fzf bat eza brew
        if not command -q $tool
            printf '%smissing: %s%s\n' (set_color red) $tool (set_color normal) >&2
            set ok 0
            set system_tools_ok 0
        end
    end
    if test $doctor_tools_ok -eq 1; and test $system_tools_ok -eq 1
        printf 'toolchain: %sok%s\n' (set_color green) (set_color normal)
    end

    # Brewfile drift check
    set -l brewfile ~/.dotfiles/Brewfile
    if test -f $brewfile
        set -l bundle_out (brew bundle check --file=$brewfile --no-upgrade 2>&1)
        set -l bundle_status $status
        if test $bundle_status -eq 0
            printf 'brewfile: %sok%s\n' (set_color green) (set_color normal)
        else
            printf 'brewfile: %sdrift detected%s\n' (set_color yellow) (set_color normal)
            printf '%s\n' $bundle_out | while read -l line
                printf '  %s\n' $line
            end
        end
    end

    # Dotfiles repo check
    set -l dotfiles ~/.dotfiles
    if test -d $dotfiles
        git -C $dotfiles fetch --quiet 2>/dev/null
        set -l dirty (git -C $dotfiles status --porcelain 2>/dev/null)
        set -l ahead_behind (git -C $dotfiles rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
        if test -n "$dirty"
            printf 'dotfiles: %suncommitted changes%s\n' (set_color yellow) (set_color normal)
        else if test -n "$ahead_behind"
            set -l behind (string split \t $ahead_behind)[1]
            set -l ahead (string split \t $ahead_behind)[2]
            if test "$ahead" -gt 0
                printf 'dotfiles: %s%s unpushed commit(s)%s\n' (set_color yellow) $ahead (set_color normal)
            else if test "$behind" -gt 0
                printf 'dotfiles: %s%s unpulled commit(s)%s\n' (set_color yellow) $behind (set_color normal)
            else
                printf 'dotfiles: %sok%s\n' (set_color green) (set_color normal)
            end
        else
            printf 'dotfiles: %sok%s\n' (set_color green) (set_color normal)
        end
    end

    # Media mount
    set -l media_mounted no
    if mount | string match -q "* on /Volumes/$MEDIA_SHARE (*"
        set media_mounted yes
    end
    if test "$media_mounted" = yes
        printf '%s is mounted at /Volumes/%s\n' $MEDIA_SHARE $MEDIA_SHARE
    else
        printf '%s is not mounted\n' $MEDIA_SHARE
    end

    # Tailscale connectivity
    set -l ts_json (tailscale status --json 2>/dev/null)
    set -l ts_state (printf '%s\n' $ts_json | jq -r .BackendState 2>/dev/null)
    if test "$ts_state" = Running
        set -l ts_ip (printf '%s\n' $ts_json | jq -r '.Self.TailscaleIPs[0]' 2>/dev/null)
        if test -n "$ts_ip"
            printf 'tailscale: %sup%s (%s)\n' (set_color green) (set_color normal) $ts_ip
        else
            printf 'tailscale: %sup%s\n' (set_color green) (set_color normal)
        end
    else
        printf 'tailscale: %sdown%s\n' (set_color yellow) (set_color normal)
    end

    # Security flags
    set -l sip_on no
    csrutil status 2>/dev/null | string match -q "*enabled*"
        and set sip_on yes
    set -l filevault_on no
    string match -q "FileVault is On*" (fdesetup status 2>/dev/null)
        and set filevault_on yes
    set -l firewall_on no
    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null \
        | string match -q "*enabled*"
        and set firewall_on yes
    set -l stealth_on no
    /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null \
        | string match -q "*is on"
        and set stealth_on yes
    set -l gatekeeper_on no
    spctl --status 2>/dev/null | string match -q "*enabled*"
        and set gatekeeper_on yes
    set -l autoupdate_on no
    set -l _au (defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null)
    test "$_au" = 1
        and set autoupdate_on yes

    set -l sec_labels SIP filevault firewall "firewall stealth" gatekeeper "security updates"
    set -l sec_flags $sip_on $filevault_on $firewall_on $stealth_on $gatekeeper_on $autoupdate_on
    for i in (seq (count $sec_labels))
        if test "$sec_flags[$i]" = yes
            printf '%s: %son%s\n' $sec_labels[$i] (set_color green) (set_color normal)
        else
            printf '%s: %soff%s\n' $sec_labels[$i] (set_color yellow) (set_color normal)
        end
    end

    # Time Machine recency check (last external backup via SnapshotDates, disk-independent)
    set -l last_snapshot (defaults export /Library/Preferences/com.apple.TimeMachine - 2>/dev/null | python3 -c "
import plistlib, sys
p = plistlib.loads(sys.stdin.buffer.read())
dates = p['Destinations'][0]['SnapshotDates']
print(dates[-1].strftime('%Y-%m-%d %H:%M:%S +0000'))
" 2>/dev/null)
    if test -n "$last_snapshot" -a "$last_snapshot" != null
        set -l backup_epoch (date -j -f "%Y-%m-%d %H:%M:%S %z" $last_snapshot "+%s" 2>/dev/null)
        if test -n "$backup_epoch"
            set -l now_epoch (date +%s)
            set -l backup_age_hours (math --scale=0 "($now_epoch - $backup_epoch) / 3600")
            set -l backup_age_days (math --scale=0 "$backup_age_hours / 24")
            set -l day_word (test $backup_age_days -eq 1; and echo day; or echo days)
            if test $backup_age_hours -le 336
                if test $backup_age_days -eq 0
                    printf 'time machine: %sok%s (%sh ago)\n' (set_color green) (set_color normal) $backup_age_hours
                else
                    printf 'time machine: %sok%s (%s %s ago)\n' (set_color green) (set_color normal) $backup_age_days $day_word
                end
            else if test $backup_age_hours -le 504
                printf 'time machine: %sstale%s (%s %s ago)\n' (set_color yellow) (set_color normal) $backup_age_days $day_word
            else
                printf 'time machine: %surgent — backup needed%s (%s %s ago)\n' (set_color red) (set_color normal) $backup_age_days $day_word
                set ok 0
            end
        end
    else
        printf 'time machine: %sno backup found%s\n' (set_color yellow) (set_color normal)
    end

    if test $ok -eq 0
        return 1
    end
end
