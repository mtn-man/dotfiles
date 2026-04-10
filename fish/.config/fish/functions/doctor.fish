function doctor --description 'Verify system is in a known-good state'
    set -l ok 1

    # Env var checks
    for var in VPN_SVC HOMELAB_HOST MEDIA_SHARE
        if not set -q $var; or test -z (string trim -- (eval echo \$$var))
            echo "doctor: "(set_color red)"error: \$$var is not set"(set_color normal) >&2
            set ok 0
        end
    end
    if test $ok -eq 0
        return 1
    end

    # Toolchain checks
    for tool in jq fd rg fzf bat eza brew tailscale transmission-remote
        if not command -q $tool
            echo "doctor: "(set_color red)"missing: $tool"(set_color normal)
            set ok 0
        end
    end

    # Collect raw signals
    set -l vpn_state (scutil --nc status "$VPN_SVC" 2>/dev/null)
    set -l tx_state (brew services info transmission-cli --json 2>/dev/null \
        | jq -r '.[0].status' 2>/dev/null)
    set -l ts_state (tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null)
    set -l media_mounted no
    if test -d "/Volumes/$MEDIA_SHARE"
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
            echo "doctor: "(set_color red)"transmission-daemon state unknown: $tx_state"(set_color normal)
    end

    set -l tx_settings /opt/homebrew/var/transmission/settings.json
    if test -f $tx_settings
        set -l bind_addr (jq -r '.["bind-address-ipv4"]' $tx_settings 2>/dev/null)
        echo "doctor: transmission bind-address-ipv4: $bind_addr"
        if test "$bind_addr" = "0.0.0.0"
            echo "doctor: "(set_color red)"warning: transmission bound to all interfaces (expected: VPN IP)"(set_color normal)
            set ok 0
        end
    else
        echo "doctor: "(set_color red)"transmission settings.json not found: $tx_settings"(set_color normal)
    end

    if test "$tx_state" = started
        if not transmission-remote "127.0.0.1:9091" -l >/dev/null 2>&1
            echo "doctor: "(set_color red)"transmission RPC not reachable"(set_color normal)
            set ok 0
        else
            echo "doctor: transmission RPC reachable"
        end
    end

    # State classification (always last)
    if test "$vpn_state[1]" = Connected \
            -a "$tx_state" = started \
            -a "$media_mounted" = no \
            -a "$ts_state" != Running
        echo "doctor: "(set_color green)"state: default (healthy)"(set_color normal)
    else if test "$vpn_state[1]" = Disconnected \
            -a "$tx_state" != started \
            -a "$media_mounted" = yes \
            -a "$ts_state" = Running
        echo "doctor: "(set_color green)"state: media (healthy)"(set_color normal)
    else
        echo "doctor: "(set_color red)"state: inconsistent"(set_color normal)
        set ok 0
    end

    if test $ok -eq 0
        return 1
    end
end
