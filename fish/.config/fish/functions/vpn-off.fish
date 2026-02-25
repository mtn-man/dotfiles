function vpn-off --description "Disconnect VPN service via scutil --nc"
    set -l svc (set -q VPN_SVC; and echo $VPN_SVC; or echo "NordVPN NordLynx")

    if not scutil --nc list | grep -q -- "$svc"
        echo "vpn-off: error: VPN service '$svc' not found." >&2
        return 1
    end

    if test (scutil --nc status "$svc" | head -n 1) = "Disconnected"
        echo "vpn-off: $svc is already disconnected."
        return 0
    end

    scutil --nc stop "$svc"
    echo "vpn-off: disconnecting..."

    set -l timeout 10
    set -l elapsed 0

    while test $elapsed -lt $timeout
        set -l vpn_status (scutil --nc status "$svc" | head -n 1)

        if test "$vpn_status" = "Disconnected"
            echo "vpn-off: success — $svc is now offline"
            return 0
        end

        sleep 1
        set elapsed (math $elapsed + 1)
    end

    echo "vpn-off: warning — disconnect requested, but status is: $vpn_status"
    return 1
end
