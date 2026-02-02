function nord-up
    scutil --nc start "NordVPN NordLynx"
    echo "Connecting to NordVPN..."

    # Poll vpn_status until "Connected" or timeout
    set -l timeout 15
    set -l elapsed 0

    while test $elapsed -lt $timeout
        # Renamed variable from 'status' to 'vpn_status'
        set -l vpn_status (scutil --nc status "NordVPN NordLynx" | head -n 1)
        
        if test "$vpn_status" = "Connected"
            echo "Success: NordVPN NordLynx is now active."
            set -l public_ip (curl -s https://ifconfig.me)
            echo "Public IP: $public_ip"
            return 0
        end

        sleep 1
        set elapsed (math $elapsed + 1)
    end

    echo "Error: Connection timed out after $timeout seconds."
    return 1
end
