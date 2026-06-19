function doctor --description 'Report system status and verify connectivity'
    set -l warnings 0
    set -l criticals 0

    # Env var checks
    for var in HOMELAB HOMELAB_LOCAL MEDIA_SHARE
        if not set -q $var
            printf '%serror: $%s is not set%s\n' (set_color red) $var (set_color normal) >&2
            set criticals (math $criticals + 1)
        end
    end

    # jq check first — required for tailscale output below
    # System toolchain (used by other functions): fd, rg, fzf, bat, eza
    set -l doctor_tools_ok 1
    for tool in jq
        if not command -q $tool
            printf '%s%s missing: proceeding in degraded state%s\n' (set_color red) $tool (set_color normal) >&2
            set warnings (math $warnings + 1)
            set doctor_tools_ok 0
        end
    end

    # Tailscale connectivity
    echo
    if test $doctor_tools_ok -eq 1
        set -l ts_json (tailscale status --json 2>/dev/null)
        set -l ts_state (printf '%s\n' $ts_json | jq -r .BackendState 2>/dev/null)
        if test "$ts_state" = Running
            set -l ts_ip (printf '%s\n' $ts_json | jq -r '.Self.TailscaleIPs[0]' 2>/dev/null)
            if test -n "$ts_ip"
                printf '%-20s up (%s)\n' tailscale: $ts_ip
            else
                printf '%-20s up\n' tailscale:
            end
        else
            printf '%-20s down\n' tailscale:
        end
    else
        printf '%-20s skipped (jq missing)\n' tailscale:
    end

    # Media mount
    set -l media_mounted no
    if mount | string match -q "* on /Volumes/$MEDIA_SHARE (*"
        set media_mounted yes
    end
    if test "$media_mounted" = yes
        printf '%-20s connected\n' 'media share:'
    else
        printf '%-20s disconnected\n' 'media share:'
    end

    # System toolchain check
    echo
    set -l system_tools_ok 1
    for tool in fd rg fzf bat eza brew
        if not command -q $tool
            printf '%smissing: %s%s\n' (set_color red) $tool (set_color normal) >&2
            set warnings (math $warnings + 1)
            set system_tools_ok 0
        end
    end
    if test $doctor_tools_ok -eq 1; and test $system_tools_ok -eq 1
        printf '%-20s %sok%s\n' toolchain: (set_color green) (set_color normal)
    end

    # Brewfile drift check
    set -l brewfile ~/.dotfiles/Brewfile
    if test -f $brewfile
        set -l bundle_out (brew bundle check --file=$brewfile --no-upgrade 2>&1)
        set -l bundle_status $status
        if test $bundle_status -eq 0
            printf '%-20s %sok%s\n' brewfile: (set_color green) (set_color normal)
        else
            printf '%-20s %sdrift detected%s\n' brewfile: (set_color yellow) (set_color normal)
            printf '%s\n' $bundle_out | while read -l line
                printf '  %s\n' $line
            end
            set warnings (math $warnings + 1)
        end
    end

    # Dotfiles repo check
    set -l dotfiles ~/.dotfiles
    if test -d $dotfiles
        git -C $dotfiles fetch --quiet 2>/dev/null
        set -l dirty (git -C $dotfiles status --porcelain 2>/dev/null)
        set -l ahead_behind (git -C $dotfiles rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
        if test -n "$dirty"
            printf '%-20s %suncommitted changes%s\n' dotfiles: (set_color yellow) (set_color normal)
            set warnings (math $warnings + 1)
        else if test -n "$ahead_behind"
            set -l behind (string split \t $ahead_behind)[1]
            set -l ahead (string split \t $ahead_behind)[2]
            if test "$ahead" -gt 0
                printf '%-20s %s%s unpushed commit(s)%s\n' dotfiles: (set_color yellow) $ahead (set_color normal)
                set warnings (math $warnings + 1)
            else if test "$behind" -gt 0
                printf '%-20s %s%s unpulled commit(s)%s\n' dotfiles: (set_color yellow) $behind (set_color normal)
                set warnings (math $warnings + 1)
            else
                printf '%-20s %sok%s\n' dotfiles: (set_color green) (set_color normal)
            end
        else
            printf '%-20s %sok%s\n' dotfiles: (set_color green) (set_color normal)
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
                    printf '%-20s %sok%s (%sh ago)\n' 'time machine:' (set_color green) (set_color normal) $backup_age_hours
                else
                    printf '%-20s %sok%s (%s %s ago)\n' 'time machine:' (set_color green) (set_color normal) $backup_age_days $day_word
                end
            else if test $backup_age_hours -le 504
                printf '%-20s %sstale%s (%s %s ago)\n' 'time machine:' (set_color yellow) (set_color normal) $backup_age_days $day_word
                set warnings (math $warnings + 1)
            else
                printf '%-20s %surgent — backup needed%s (%s %s ago)\n' 'time machine:' (set_color red) (set_color normal) $backup_age_days $day_word
                set criticals (math $criticals + 1)
            end
        end
    else
        printf '%-20s %sno backup found%s\n' 'time machine:' (set_color yellow) (set_color normal)
        set warnings (math $warnings + 1)
    end

    # Security flags
    echo
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

    set -l sec_labels SIP filevault firewall "firewall stealth" "security updates" gatekeeper
    set -l sec_flags $sip_on $filevault_on $firewall_on $stealth_on $autoupdate_on $gatekeeper_on
    set -l sec_crits crit crit warn warn warn warn
    for i in (seq (count $sec_labels))
        if test "$sec_flags[$i]" = yes
            printf '%-20s %son%s\n' "$sec_labels[$i]:" (set_color green) (set_color normal)
        else if test "$sec_crits[$i]" = crit
            printf '%-20s %soff%s\n' "$sec_labels[$i]:" (set_color red) (set_color normal)
            set criticals (math $criticals + 1)
        else
            printf '%-20s %soff%s\n' "$sec_labels[$i]:" (set_color yellow) (set_color normal)
            set warnings (math $warnings + 1)
        end
    end

    # Summary
    if test $criticals -gt 0 -o $warnings -gt 0
        set -l parts
        if test $criticals -gt 0
            set -l crit_word (test $criticals -eq 1; and echo critical; or echo criticals)
            set -a parts (printf '%s%d %s%s' (set_color red) $criticals $crit_word (set_color normal))
        end
        if test $warnings -gt 0
            set -l warn_word (test $warnings -eq 1; and echo warning; or echo warnings)
            set -a parts (printf '%s%d %s%s' (set_color yellow) $warnings $warn_word (set_color normal))
        end
        printf '\n%-20s %s\n' summary: (string join ', ' $parts)
    end

    echo
    if test $criticals -gt 0
        return 2
    else if test $warnings -gt 0
        return 1
    end
end
