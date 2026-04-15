function doctor --description 'Report system status and verify transmission VPN safety'
    set -l ok 1

    # Env var checks
    for var in VPN_SVC HOMELAB_HOST MEDIA_SHARE
        if test -z (string join "" $$var)
            printf 'doctor: %serror: $%s is not set%s\n' (set_color red) $var (set_color normal) >&2
            set ok 0
        end
    end
    if test $ok -eq 0
        return 1
    end

    # Toolchain checks
    # Required by doctor: jq, tailscale, transmission-remote
    # System toolchain (used by other functions): fd, rg, fzf, bat, eza
    for tool in jq fd rg fzf bat eza brew tailscale transmission-remote
        if not command -q $tool
            printf 'doctor: %smissing: %s%s\n' (set_color red) $tool (set_color normal)
            set ok 0
        end
    end
    if test $ok -eq 0
        return 1
    end
    echo "doctor: toolchain: ok"

    # Collect raw signals
    set -l vpn_state (scutil --nc status "$VPN_SVC" 2>/dev/null)
    set -l vpn_iface (string match -rg 'InterfaceName : (\S+)' $vpn_state)
    set -l vpn_status $vpn_state[1]
    test -z "$vpn_status"; and set vpn_status unknown
    set -l tx_pass (security find-generic-password -s transmission-rpc -a user -w 2>/dev/null)
    set -l tx_up no
    if test -z "$tx_pass"
        printf 'doctor: %swarning: transmission RPC credentials not found in keychain%s\n' (set_color yellow) (set_color normal)
    else
        transmission-remote "127.0.0.1:9091" -n "user:$tx_pass" -l >/dev/null 2>&1
            and set tx_up yes
    end
    set -l ts_state (tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null)
    if test -z "$ts_state"
        printf 'doctor: %swarning: tailscale status unavailable%s\n' (set_color yellow) (set_color normal)
        set ts_state unknown
    end
    set -l ts_ip ''
    test "$ts_state" = Running
        and set ts_ip (tailscale ip -4 2>/dev/null)
    set -l tx_settings /opt/homebrew/var/transmission/settings.json
    set -l media_mounted no
    if mount | string match -q "* on /Volumes/$MEDIA_SHARE (*"
        set media_mounted yes
    end
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

    # Display: mount, VPN (delegate for public IP), tailscale
    if test "$media_mounted" = yes
        echo "doctor: $MEDIA_SHARE is mounted at /Volumes/$MEDIA_SHARE"
    else
        echo "doctor: $MEDIA_SHARE is not mounted"
    end
    vpn status 2>&1 | string replace --regex '^vpn:' 'doctor:'
    echo "doctor: tailscale: $ts_state"
    if test -n "$ts_ip"
        echo "doctor: tailscale IP: $ts_ip"
    end

    # Display: transmission
    if test "$tx_up" = yes
        echo "doctor: transmission-daemon is on"
    else
        echo "doctor: transmission-daemon is off"
    end

    if test "$tx_up" = yes
        if not test -f $tx_settings
            printf 'doctor: %swarning: transmission settings.json not found: %s%s\n' \
                (set_color yellow) $tx_settings (set_color normal)
        else
            set -l bind_addr (jq -r '.["bind-address-ipv4"]' $tx_settings 2>/dev/null)
            echo "doctor: transmission bind-address-ipv4: $bind_addr"
            if test "$vpn_status" = Connected
                if test -z "$vpn_iface"
                    printf 'doctor: %swarning: VPN connected but interface name unknown; cannot verify transmission bind address%s\n' \
                        (set_color yellow) (set_color normal)
                else
                    set -l expected_vpn_ip (ifconfig "$vpn_iface[1]" 2>/dev/null | string match -rg '\binet (\S+)')[1]
                    if test -z "$expected_vpn_ip"
                        printf 'doctor: %swarning: could not read IP for VPN interface %s; cannot verify transmission bind address%s\n' \
                            (set_color yellow) "$vpn_iface" (set_color normal)
                    else if test "$bind_addr" != "$expected_vpn_ip"
                        printf 'doctor: %serror: transmission not bound to VPN interface (got: %s, expected: %s)%s\n' \
                            (set_color red) $bind_addr $expected_vpn_ip (set_color normal)
                        set ok 0
                    end
                end
            else
                if test "$bind_addr" = "0.0.0.0"
                    printf 'doctor: %serror: transmission running unprotected — bind address is 0.0.0.0%s\n' \
                        (set_color red) (set_color normal) >&2
                    set ok 0
                else if ifconfig 2>/dev/null | string match -q "*inet $bind_addr *"
                    printf 'doctor: %serror: transmission running unprotected — bind address %s is reachable%s\n' \
                        (set_color red) $bind_addr (set_color normal) >&2
                    set ok 0
                else
                    printf 'doctor: %swarning: transmission running without VPN — kill switch active%s\n' \
                        (set_color yellow) (set_color normal)
                end
            end
        end
    end

    # Display: security
    if test "$sip_on" = yes
        echo "doctor: SIP: on"
    else
        printf 'doctor: %sSIP: off%s\n' (set_color yellow) (set_color normal)
    end
    if test "$filevault_on" = yes
        echo "doctor: filevault: on"
    else
        printf 'doctor: %sfilevault: off%s\n' (set_color yellow) (set_color normal)
    end
    if test "$firewall_on" = yes
        echo "doctor: firewall: on"
    else
        printf 'doctor: %sfirewall: off%s\n' (set_color yellow) (set_color normal)
    end
    if test "$stealth_on" = yes
        echo "doctor: firewall stealth: on"
    else
        printf 'doctor: %sfirewall stealth: off%s\n' (set_color yellow) (set_color normal)
    end
    if test "$gatekeeper_on" = yes
        echo "doctor: gatekeeper: on"
    else
        printf 'doctor: %sgatekeeper: off%s\n' (set_color yellow) (set_color normal)
    end
    if test "$autoupdate_on" = yes
        echo "doctor: auto updates: on"
    else
        printf 'doctor: %sauto updates: off%s\n' (set_color yellow) (set_color normal)
    end

    if test $ok -eq 0
        return 1
    end
end
