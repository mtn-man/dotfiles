function _vpn_public_ip
    curl -fsS --max-time 5 https://ifconfig.co 2>/dev/null
        or curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null
end

function _vpn_wait_for --argument-names svc target_state timeout
    set -l elapsed 0
    while test $elapsed -lt $timeout
        set -l state (scutil --nc status "$svc")
        if test "$state[1]" = "$target_state"
            return 0
        end
        sleep 1
        set elapsed (math "$elapsed + 1")
    end
    return 1
end

function vpn --description 'Manage VPN service (on/off/status) via scutil --nc'

    set -l sub $argv[1]
    
    # VPN_SVC is set as an environment variable in config.fish
    # Ensure the specified VPN service exists in the network configuration
    if not scutil --nc list | grep -q -- "$VPN_SVC"
        echo "vpn: error: VPN service '$VPN_SVC' not found." >&2
        return 1
    end
    
    switch "$sub"
    
        case on
            set -l state (scutil --nc status "$VPN_SVC")
            if test "$state[1]" = "Connected"
                echo "vpn: $VPN_SVC is already connected"
                return 0
            end
            
            if not scutil --nc start "$VPN_SVC"
                echo "vpn: error: failed to start $VPN_SVC" >&2
                return 1
            end
            
            echo "vpn: connecting..."
            if _vpn_wait_for "$VPN_SVC" Connected 15
                echo "vpn: $VPN_SVC active"
                set -l ip (_vpn_public_ip)
                if test -n "$ip"
                    echo "vpn: public IP: $ip (VPN)"
                else
                    echo "vpn: public IP lookup failed -- vpn status OK"
                end
                return 0
            end
            echo "vpn: error -- connection timed out after 15 seconds." >&2
            return 1
            
        case off
            set -l state (scutil --nc status "$VPN_SVC")
            if test "$state[1]" = "Disconnected"
                echo "vpn: $VPN_SVC is already disconnected."
                return 0
            end
            scutil --nc stop "$VPN_SVC"
            echo "vpn: disconnecting..."
            if _vpn_wait_for "$VPN_SVC" Disconnected 10
                echo "vpn: $VPN_SVC offline"
                return 0
            end
            echo "vpn: warning -- disconnect requested, but status is unknown."
            return 1
            
        case status
            set -l state (scutil --nc status "$VPN_SVC")
            switch "$state[1]"
                case Connected
                    echo "vpn: $VPN_SVC is connected"
                    set -l ip (_vpn_public_ip)
                    if test -n "$ip"
                        echo "vpn: public IP: $ip"
                    else
                        echo "vpn: public IP lookup failed"
                    end
                case Disconnected
                    echo "vpn: $VPN_SVC is disconnected"
                case '*'
                    echo "vpn: $VPN_SVC status: $state[1]"
            end
            
        case '*'
            echo "Usage: vpn [on|off|status]" >&2
            return 1
    end
end
