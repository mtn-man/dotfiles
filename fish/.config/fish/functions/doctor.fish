function doctor --description 'Verify system is in a known-good state'
    set -l ok 1

    # Env var checks
    for var in VPN_SVC HOMELAB_HOST MEDIA_SHARE
        if not set -q $var; or test -z (string trim -- (eval echo \$$var))
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
    set -l tx_state (brew services info transmission-cli --json 2>/dev/null \
        | jq -r '.[0].status' 2>/dev/null)
    set -l ts_state (tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null)
    if test -z "$ts_state"
        printf 'doctor: %stailscale status unavailable%s\n' (set_color red) (set_color normal)
        set ok 0
        set ts_state unknown
    end
    set -l media_mounted no
    if mount | string match -q "* on /Volumes/$MEDIA_SHARE (*"
        set media_mounted yes
    end

    # Display: mount, VPN (delegate for public IP), tailscale
    if test "$media_mounted" = yes
        echo "doctor: $MEDIA_SHARE is mounted at /Volumes/$MEDIA_SHARE"
    else
        echo "doctor: $MEDIA_SHARE is not mounted"
    end
    vpn status 2>&1 | string replace --regex '^vpn:' 'doctor:'
    echo "doctor: tailscale: $ts_state"

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
                set -l vpn_iface (scutil --nc status "$VPN_SVC" 2>/dev/null \
                    | string match -rg 'InterfaceName : (\S+)')
                set -l expected_vpn_ip ""
                test -n "$vpn_iface"
                    and set expected_vpn_ip (ipconfig getifaddr "$vpn_iface" 2>/dev/null)
                if test -n "$expected_vpn_ip"; and test "$bind_addr" != "$expected_vpn_ip"
                    set -l warn "warning: transmission not bound to VPN interface"
                    set -l detail "(got: $bind_addr, expected: $expected_vpn_ip)"
                    printf 'doctor: %s%s %s%s\n' \
                        (set_color red) $warn $detail (set_color normal)
                    set ok 0
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

    if test "$vpn_status" = Connected; and test "$ts_state" = Running
        printf 'doctor: %serror: Tailscale running while VPN is connected%s\n' \
            (set_color red) (set_color normal)
        set ok 0
    end

    # State classification (always last)
    if test "$vpn_status" = Connected
        and test "$tx_state" = started
        and test "$media_mounted" = no
        and test "$ts_state" != Running
        printf 'doctor: %sstate: default (healthy)%s\n' (set_color green) (set_color normal)
    else if test "$vpn_status" = Disconnected
        and test "$tx_state" != started
        and test "$media_mounted" = yes
        and test "$ts_state" = Running
        printf 'doctor: %sstate: media (healthy)%s\n' (set_color green) (set_color normal)
    else
        printf 'doctor: %sstate: inconsistent%s\n' (set_color red) (set_color normal)
        set ok 0
    end

    if test $ok -eq 0
        return 1
    end
end
