function vpn-on --description "Connect VPN service via scutil --nc"
    set -l svc (set -q VPN_SVC; and echo $VPN_SVC; or echo "NordVPN NordLynx")

    if not scutil --nc list | grep -q -- "$svc"
        echo "vpn-on: error: VPN service '$svc' not found. Check VPN app configuration." >&2
        return 1
    end

    if test (scutil --nc status "$svc" | head -n 1) = "Connected"
        echo "vpn-on: $svc is already connected."
        return 0
    end

    scutil --nc start "$svc"; or begin
        echo "vpn-on: error: failed to start $svc" >&2
        return 1
    end
    echo "vpn-on: connecting to VPN..."

    set -l timeout 15
    set -l elapsed 0

    while test $elapsed -lt $timeout
        set -l vpn_status (scutil --nc status "$svc" | head -n 1)

        if test "$vpn_status" = "Connected"
            echo "vpn-on: success — $svc is now active."
            set -l public_ip (curl -fsS --max-time 5 https://ifconfig.co 2>/dev/null; or echo "unknown")
            echo "vpn-on: public IP: $public_ip"
            return 0
        end

        sleep 1
        set elapsed (math $elapsed + 1)
    end

    echo "vpn-on: error — connection timed out after $timeout seconds." >&2
    return 1
end
