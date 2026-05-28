function doctor --description 'Report system status and verify connectivity'
    set -l ok 1

    # Env var checks
    for var in HOMELAB HOMELAB_LOCAL MEDIA_SHARE
        if not set -q $var
            printf 'doctor: %serror: $%s is not set%s\n' (set_color red) $var (set_color normal) >&2
            set ok 0
        end
    end

    # Toolchain checks
    # Required by doctor: jq (tailscale JSON parsing)
    # System toolchain (used by other functions): fd, rg, fzf, bat, eza
    set -l doctor_tools_ok 1
    for tool in jq
        if not command -q $tool
            printf 'doctor: %s%s missing: proceeding in degraded state%s\n' (set_color red) $tool (set_color normal) >&2
            set ok 0
            set doctor_tools_ok 0
        end
    end
    set -l system_tools_ok 1
    for tool in fd rg fzf bat eza brew
        if not command -q $tool
            printf 'doctor: %smissing: %s%s\n' (set_color red) $tool (set_color normal) >&2
            set ok 0
            set system_tools_ok 0
        end
    end
    if test $doctor_tools_ok -eq 1; and test $system_tools_ok -eq 1
        printf 'doctor: toolchain: %sok%s\n' (set_color green) (set_color normal)
    end

    # Media mount
    set -l media_mounted no
    if mount | string match -q "* on /Volumes/$MEDIA_SHARE (*"
        set media_mounted yes
    end
    if test "$media_mounted" = yes
        printf 'doctor: %s is mounted at /Volumes/%s\n' $MEDIA_SHARE $MEDIA_SHARE
    else
        printf 'doctor: %s is not mounted\n' $MEDIA_SHARE
    end

    # Tailscale connectivity
    set -l ts_json (tailscale status --json 2>/dev/null)
    set -l ts_state (echo $ts_json | jq -r .BackendState 2>/dev/null)
    if test "$ts_state" = Running
        set -l ts_ip (echo $ts_json | jq -r '.Self.TailscaleIPs[0]' 2>/dev/null)
        if test -n "$ts_ip"
            printf 'doctor: tailscale: %sup%s (%s)\n' (set_color green) (set_color normal) $ts_ip
        else
            printf 'doctor: tailscale: %sup%s\n' (set_color green) (set_color normal)
        end
    else
        printf 'doctor: tailscale: %sdown%s\n' (set_color yellow) (set_color normal)
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

    set -l sec_labels SIP filevault firewall "firewall stealth" gatekeeper "auto updates"
    set -l sec_flags $sip_on $filevault_on $firewall_on $stealth_on $gatekeeper_on $autoupdate_on
    for i in (seq (count $sec_labels))
        if test "$sec_flags[$i]" = yes
            printf 'doctor: %s: %son%s\n' $sec_labels[$i] (set_color green) (set_color normal)
        else
            printf 'doctor: %s: %soff%s\n' $sec_labels[$i] (set_color yellow) (set_color normal)
        end
    end

    if test $ok -eq 0
        return 1
    end
end
