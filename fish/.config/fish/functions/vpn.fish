function vpn --description 'Manage VPN service (on/off) via scutil --nc'
    set -l sub $argv[1]
    # Resolve service name from environment variable or default to NordLynx
    set -l svc (set -q VPN_SVC; and echo $VPN_SVC; or echo "NordVPN NordLynx")

    # Ensure the specified VPN service exists in the network configuration
    if not scutil --nc list | grep -q -- "$svc"
        echo "vpn: error: VPN service '$svc' not found." >&2
        return 1
    end

    switch "$sub"
        case on
            if test (scutil --nc status "$svc" | head -n 1) = "Connected"
                echo "vpn: $svc is already connected"
                return 0
            end

            scutil --nc start "$svc"; or begin
                echo "vpn: error: failed to start $svc" >&2
                return 1
            end
            echo "vpn: connecting to vpn..."

            set -l timeout 15
            set -l elapsed 0
            while test $elapsed -lt $timeout
                if test (scutil --nc status "$svc" | head -n 1) = "Connected"
                    echo "vpn: $svc active"
                    
                    # Attempt public IP lookup for confirmation
                    set -l public_ip (curl -fsS --max-time 5 https://ifconfig.co 2>/dev/null; or curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null)
                    if test -n "$public_ip"
                        echo "vpn: public IP: $public_ip (vpn)"
                    else
                        echo "vpn: public IP lookup failed — vpn status OK"
                    end
                    return 0
                end
                sleep 1
                set elapsed (math $elapsed + 1)
            end
            echo "vpn: error — connection timed out after $timeout seconds." >&2
            return 1

        case off
            if test (scutil --nc status "$svc" | head -n 1) = "Disconnected"
                echo "vpn: $svc is already disconnected."
                return 0
            end

            scutil --nc stop "$svc"
            echo "vpn: disconnecting..."

            set -l timeout 10
            set -l elapsed 0
            while test $elapsed -lt $timeout
                if test (scutil --nc status "$svc" | head -n 1) = "Disconnected"
                    echo "vpn: $svc offline"
                    return 0
                end
                sleep 1
                set elapsed (math $elapsed + 1)
            end
            echo "vpn: warning — disconnect requested, but status is unknown."
            return 1

        case '*'
            echo "Usage: vpn [on|off]" >&2
            return 1
    end
end
