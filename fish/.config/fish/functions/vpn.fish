function __vpn_public_ip
    set -l ip_timeout 5
    curl -fsS --max-time $ip_timeout https://ifconfig.co 2>/dev/null
        or curl -fsS --max-time $ip_timeout https://api.ipify.org 2>/dev/null
end

function __vpn_print_ip
    set -l ip (__vpn_public_ip)
    if test -n "$ip"
        echo "vpn: public IP: $ip"
    else
        echo "vpn: public IP lookup failed"
    end
end

function __vpn_wait_for --argument-names svc target_state timeout
    set -l elapsed 0
    while test $elapsed -lt $timeout
        set -l state (scutil --nc status "$svc")
        if test "$state[1]" = "$target_state"
            return
        end
        sleep 1
        set elapsed (math "$elapsed + 1")
    end
    return 1
end

function __vpn_tailscale_state
    tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null
end

function vpn --description 'Manage network mode (normal/media) and VPN service'

    set -l sub $argv[1]

    if not scutil --nc show "$VPN_SVC" >/dev/null 2>&1
        echo "vpn: error: VPN service '$VPN_SVC' not found." >&2
        return 1
    end

    set -l vpn_timeout 10

    switch "$sub"

        case on
            # Enforce VPN mode: Tailscale down, VPN connected

            # Unmount media share first — it routes via Tailscale and won't survive the transition
            if set -q MEDIA_SHARE
                if mount 2>/dev/null | string match -q "* on /Volumes/$MEDIA_SHARE (*"
                    echo "vpn: unmounting $MEDIA_SHARE before network change..."
                    if not diskutil unmount "/Volumes/$MEDIA_SHARE" >/dev/null 2>&1
                        echo "vpn: error: could not unmount $MEDIA_SHARE (disk busy)" >&2
                        return 1
                    end
                    echo "vpn: $MEDIA_SHARE unmounted"
                end
            end

            set -l ts_state (__vpn_tailscale_state)
            if test "$ts_state" = Running
                echo "vpn: bringing Tailscale down..."
                if not tailscale down >/dev/null 2>&1
                    echo "vpn: error: tailscale down failed" >&2
                    return 1
                end
                echo "vpn: Tailscale offline"
            end

            set -l vpn_state (scutil --nc status "$VPN_SVC")
            if test "$vpn_state[1]" = Connected
                echo "vpn: vpn mode already active"
                __vpn_print_ip
                return 0
            end

            if not scutil --nc start "$VPN_SVC"
                echo "vpn: error: failed to start $VPN_SVC" >&2
                return 1
            end
            echo "vpn: connecting VPN..."
            if __vpn_wait_for "$VPN_SVC" Connected $vpn_timeout
                echo "vpn: $VPN_SVC active"
                __vpn_print_ip
                return 0
            end
            echo "vpn: error: connection timed out after $vpn_timeout seconds." >&2
            return 1

        case off
            # Enforce Tailscale mode: VPN disconnected, Tailscale up
            set -l vpn_state (scutil --nc status "$VPN_SVC")
            set -l ts_state (__vpn_tailscale_state)

            if test "$vpn_state[1]" = Disconnected; and test "$ts_state" = Running
                echo "vpn: tailscale mode already active"
                return 0
            end

            if test "$vpn_state[1]" != Disconnected
                scutil --nc stop "$VPN_SVC"
                echo "vpn: disconnecting VPN..."
                if not __vpn_wait_for "$VPN_SVC" Disconnected $vpn_timeout
                    echo "vpn: warning: disconnect requested, but status is unknown." >&2
                    return 1
                end
                echo "vpn: $VPN_SVC offline"
            end

            if test "$ts_state" != Running
                echo "vpn: starting Tailscale..."
                if not tailscale up 2>/dev/null
                    echo "vpn: error: tailscale up failed" >&2
                    return 1
                end
                echo "vpn: Tailscale up"
            end

            echo "vpn: tailscale mode active"
            return 0

        case status
            set -l vpn_state (scutil --nc status "$VPN_SVC")
            set -l ts_json (tailscale status --json 2>/dev/null)
            set -l ts_state (echo $ts_json | jq -r .BackendState 2>/dev/null)
            set -l vpn_connected no
            set -l ts_running no
            test "$vpn_state[1]" = Connected; and set vpn_connected yes
            test "$ts_state" = Running; and set ts_running yes

            if test "$vpn_connected" = yes; and test "$ts_running" = no
                echo "vpn: vpn mode active"
                __vpn_print_ip
            else if test "$vpn_connected" = no; and test "$ts_running" = yes
                echo "vpn: tailscale mode active"
                set -l ts_ip (echo $ts_json | jq -r '.Self.TailscaleIPs[0]' 2>/dev/null)
                if test -n "$ts_ip"
                    echo "vpn: Tailscale IP: $ts_ip"
                end
            else if test "$vpn_connected" = yes; and test "$ts_running" = yes
                echo "vpn: warning: invalid state — both VPN and Tailscale are active" >&2
                echo "vpn: run 'vpn on' to enter vpn mode" >&2
            else
                echo "vpn: warning: invalid state — neither VPN nor Tailscale is active" >&2
                echo "vpn: run 'vpn on' to enter vpn mode" >&2
            end

        case toggle
            set -l vpn_state (scutil --nc status "$VPN_SVC")
            set -l ts_state (__vpn_tailscale_state)

            if test "$vpn_state[1]" = Connected; and test "$ts_state" != Running
                vpn off
                return $status
            else if test "$vpn_state[1]" != Connected; and test "$ts_state" = Running
                vpn on
                return $status
            else
                echo "vpn: invalid state detected — resolving to vpn mode"
                vpn on
                return $status
            end

        case '*'
            echo "Usage: vpn [on|off|status|toggle]" >&2
            return 1
    end
end
