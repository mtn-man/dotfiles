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

    # Preflight: ensure Transmission RPC is reachable
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
