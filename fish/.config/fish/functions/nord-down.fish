function nord-down
    set -l svc (set -q NORD_SVC; and echo $NORD_SVC; or echo "NordVPN NordLynx")

    if not scutil --nc list | grep -q -- "$svc"
        echo "nord-down: error: VPN service '$svc' not found." >&2
        return 1
    end

    if test (scutil --nc status "$svc" | head -n 1) = "Disconnected"
        echo "nord-down: $svc is already disconnected."
        return 0
    end

    scutil --nc stop "$svc"
    echo "nord-down: disconnecting..."

    set -l timeout 10
    set -l elapsed 0

    while test $elapsed -lt $timeout
        set -l vpn_status (scutil --nc status "$svc" | head -n 1)

        if test "$vpn_status" = "Disconnected"
            echo "nord-down: success — $svc is now offline."
            return 0
        end

        sleep 1
        set elapsed (math $elapsed + 1)
    end

    echo "nord-down: warning — disconnect requested, but status is: $vpn_status"
    return 1
end
