function tm --description 'Manage Transmission-CLI services and magnet links'
    set -l host "$HOMELAB:9091"

    if not command -q transmission-remote
        echo "tm: transmission-remote not found" >&2
        return 127
    end

    switch "$argv[1]"
        case ping
            transmission-remote "$host" -st
            return
    end

    # Preflight: fast port probe first so a dead tunnel fails in ~1s instead of
    # waiting out the OS TCP connect timeout, then confirm the RPC actually responds.
    # -w is Ncat's (nmap-ncat) connect timeout, unlike classic BSD/GNU nc where
    # -w is idle-only and doesn't bound connect() at all.
    set -l host_ip (string split ':' $host)[1]
    set -l host_port (string split ':' $host)[2]
    if not nc -z -w 1 $host_ip $host_port >/dev/null 2>&1
        echo "tm: Transmission RPC at $host is unreachable (connection timed out)" >&2
        echo "tm: ensure tailscale is active and the Transmission server is up." >&2
        return 1
    end
    if not transmission-remote "$host" -l >/dev/null 2>&1
        echo "tm: Transmission RPC not reachable at $host" >&2
        echo "tm: ensure tailscale is active and homelab is up." >&2
        return 1
    end

    set -l input
    if set -q argv[1]
        set input (string trim -- "$argv[1]")
    else
        set input (__paste)
    end

    if test -z "$input"
        echo "tm: clipboard is empty" >&2
        return 1
    end

    if string match -q "*.torrent" -- "$input"
        if not test -f "$input"
            echo "tm: file not found: $input" >&2
            return 1
        end
        if transmission-remote "$host" -a "$input"
            echo "tm: torrent added"
            echo "tm: track progress at http://$host/transmission/web/"
        end
        return
    end

    if not string match -rq '^magnet:\?' -- "$input"
        echo "tm: not a magnet link or .torrent file" >&2
        return 1
    end

    if not string match -rq 'xt=urn:btih:' -- "$input"
        echo "tm: magnet missing xt=urn:btih:" >&2
        return 1
    end

    if transmission-remote "$host" -a "$input"
        echo "tm: magnet added"
        echo "tm: track progress at http://$host/transmission/web/"
    end
end
