function nord-down
    scutil --nc stop "NordVPN NordLynx"
    echo "Disconnecting..."
    
    sleep 2
    set -l vpn_status (scutil --nc status "NordVPN NordLynx" | head -n 1)
    
    if test "$vpn_status" = "Disconnected"
        echo "Success: NordVPN is now offline."
    else
        echo "Disconnection command sent, but status is: $vpn_status"
    end
end
