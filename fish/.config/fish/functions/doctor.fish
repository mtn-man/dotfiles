function doctor --description 'Verify system is in a known-good state'
    set -l ok 1

    # 1. Env var checks (silent on pass)
    for var in VPN_SVC HOMELAB_HOST MEDIA_SHARE
        if test -z "$$var"
            echo "doctor: error: \$$var is not set" >&2
            set ok 0
        end
    end

    # 2. Toolchain checks (silent on pass)
    for tool in jq fd rg fzf bat eza brew tailscale transmission-remote
        if not command -q $tool
            echo "doctor: missing: $tool"
            set ok 0
        end
    end

    # 3. System state — display via existing functions, collect raw signals for classification
    media status 2>&1 | string replace --regex '^media:' 'doctor:'

    set -l ts_state (tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null)
    echo "doctor: tailscale: $ts_state"

    # Raw signals needed for state classification
    set -l vpn_state (scutil --nc status "$VPN_SVC" 2>/dev/null)
    set -l tx_state (brew services info transmission-cli --json 2>/dev/null \
        | jq -r '.[0].status' 2>/dev/null)
    set -l media_mounted no
    if test -d "/Volumes/$MEDIA_SHARE"
        set media_mounted yes
    end

    # 4. State classification
    if test "$vpn_state[1]" = Connected \
            -a "$tx_state" = started \
            -a "$media_mounted" = no \
            -a "$ts_state" != Running
        echo "doctor: state: default (healthy)"
    else if test "$vpn_state[1]" = Disconnected \
            -a "$tx_state" != started \
            -a "$media_mounted" = yes \
            -a "$ts_state" = Running
        echo "doctor: state: media (healthy)"
    else
        echo "doctor: state: inconsistent"
        set ok 0
    end

    # 5. Transmission security
    set -l tx_settings /opt/homebrew/var/transmission/settings.json
    if test -f $tx_settings
        set -l bind_addr (jq -r '.["bind-address-ipv4"]' $tx_settings 2>/dev/null)
        echo "doctor: transmission bind-address-ipv4: $bind_addr"
        if test "$bind_addr" = "0.0.0.0"
            echo "doctor: warning: transmission bound to all interfaces (expected: VPN IP)"
            set ok 0
        end
    else
        echo "doctor: transmission settings.json not found: $tx_settings"
    end

    if test "$tx_state" = started
        if not transmission-remote "127.0.0.1:9091" -l >/dev/null 2>&1
            echo "doctor: transmission RPC not reachable"
            set ok 0
        else
            echo "doctor: transmission RPC reachable"
        end
    end

    if test $ok -eq 0
        return 1
    end
end
