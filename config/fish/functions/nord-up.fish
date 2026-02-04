function nord-up
    set -l svc (set -q NORD_SVC; and echo $NORD_SVC; or echo "NordVPN NordLynx")

    if not scutil --nc list | grep -q -- "$svc"
        echo "nord-up: error: VPN service '$svc' not found. Check NordVPN app configuration." >&2
        return 1
    end

    if test (scutil --nc status "$svc" | head -n 1) = "Connected"
        echo "nord-up: $svc is already connected."
        return 0
    end

    scutil --nc start "$svc"; or begin
        echo "nord-up: error: failed to start $svc" >&2
        return 1
    end
    echo "nord-up: connecting to NordVPN..."

    set -l timeout 15
    set -l elapsed 0

    while test $elapsed -lt $timeout
        set -l vpn_status (scutil --nc status "$svc" | head -n 1)

        if test "$vpn_status" = "Connected"
            echo "nord-up: success — $svc is now active."
            set -l public_ip (curl -fsS --max-time 5 https://ifconfig.co 2>/dev/null; or echo "unknown")
            echo "nord-up: public IP: $public_ip"
            return 0
        end

        sleep 1
        set elapsed (math $elapsed + 1)
    end

    echo "nord-up: error — connection timed out after $timeout seconds." >&2
    return 1
end
