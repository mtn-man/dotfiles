function doctor --description 'Verify system is in a known-good state'
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
    for tool in jq fd rg fzf bat eza brew tailscale transmission-remote
        if not command -q $tool
            printf 'doctor: %smissing: %s%s\n' (set_color red) $tool (set_color normal)
            set ok 0
        end
    end
    if test $ok -eq 0
        return 1
    end

    # Collect raw signals
    set -l vpn_state (scutil --nc status "$VPN_SVC" 2>/dev/null)
    set -l vpn_status $vpn_state[1]
    set -l vpn_iface (string match -rg 'InterfaceName : (\S+)' $vpn_state)
    set -l tx_state (brew services info transmission-cli --json 2>/dev/null \
        | jq -r '.[0].status' 2>/dev/null)
    set -l ts_state (tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null)
    if test -z "$ts_state"
        printf 'doctor: %stailscale status unavailable%s\n' (set_color red) (set_color normal)
        set ok 0
        set ts_state unknown
    end
    set -l ts_ip ''
    test "$ts_state" = Running
        and set ts_ip (tailscale ip -4 2>/dev/null)
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
    set -l gatekeeper_on no
    spctl --status 2>/dev/null | string match -q "*enabled*"
        and set gatekeeper_on yes
    set -l autoupdate_on no
    set -l _au (defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null)
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
        echo "doctor: public IP: $ts_ip"
    end

    # Display: transmission (daemon + security grouped)
    switch "$tx_state"
        case started
            echo "doctor: transmission-daemon is on"
        case none
            echo "doctor: transmission-daemon is off"
        case '*'
            printf 'doctor: %stransmission-daemon state unknown: %s%s\n' \
                (set_color red) $tx_state (set_color normal)
    end

    if test "$tx_state" = started
        set -l tx_settings /opt/homebrew/var/transmission/settings.json
        if not test -f $tx_settings
            printf 'doctor: %stransmission settings.json not found: %s%s\n' \
                (set_color red) $tx_settings (set_color normal)
        else
            set -l bind_addr (jq -r '.["bind-address-ipv4"]' $tx_settings 2>/dev/null)
            echo "doctor: transmission bind-address-ipv4: $bind_addr"
            if test "$vpn_status" = Connected
                if test -n "$vpn_iface"
                    set -l expected_vpn_ip (ipconfig getifaddr "$vpn_iface" 2>/dev/null)
                    if test -n "$expected_vpn_ip"
                        and test "$bind_addr" != "$expected_vpn_ip"
                        printf 'doctor: %swarning: transmission not bound to VPN interface (got: %s, expected: %s)%s\n' \
                            (set_color red) $bind_addr $expected_vpn_ip (set_color normal)
                        set ok 0
                    end
                end
            end
        end
        if not transmission-remote "127.0.0.1:9091" -l >/dev/null 2>&1
            printf 'doctor: %stransmission RPC not reachable%s\n' (set_color red) (set_color normal)
            set ok 0
        else
            echo "doctor: transmission RPC reachable"
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

    if test "$vpn_status" = Connected
        and test "$ts_state" = Running
        printf 'doctor: %serror: Tailscale running while VPN is connected%s\n' \
            (set_color red) (set_color normal)
        set ok 0
    end

    # State classification (always last)
    if test "$vpn_status" = Connected
        and test "$tx_state" = started
        and test "$media_mounted" = no
        and test "$ts_state" != Running
        and test "$filevault_on" = yes
        and test "$firewall_on" = yes
        and test "$sip_on" = yes
        and test "$gatekeeper_on" = yes
        and test "$autoupdate_on" = yes
        printf 'doctor: %sstate: default (healthy)%s\n' (set_color green) (set_color normal)
    else if test "$vpn_status" = Disconnected
        and test "$tx_state" != started
        and test "$media_mounted" = yes
        and test "$ts_state" = Running
        and test "$filevault_on" = yes
        and test "$firewall_on" = yes
        and test "$sip_on" = yes
        and test "$gatekeeper_on" = yes
        and test "$autoupdate_on" = yes
        printf 'doctor: %sstate: media (healthy)%s\n' (set_color green) (set_color normal)
    else
        printf 'doctor: %sstate: inconsistent%s\n' (set_color red) (set_color normal)
        set ok 0
    end

    if test $ok -eq 0
        return 1
    end
end
