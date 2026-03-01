function tm --description 'Manage Transmission-CLI services and magnet links'
    set -l host "127.0.0.1:9091"

    # 1. Check if the first argument is a service management subcommand
    switch "$argv[1]"
        case on
            brew services start transmission-cli
            return
        case off
            brew services stop transmission-cli
            return
        case re restart
            brew services restart transmission-cli
            return
        case ping
            transmission-remote "$host" -st
            return
    end

    # 2. Existing Magnet Link Logic
    # dependency check
    if not command -q transmission-remote
        echo "tm: transmission-remote not found (brew install transmission-cli)" >&2
        return 127
    end

    # Preflight: ensure Transmission daemon is running and RPC is reachable
    if not transmission-remote "$host" -l >/dev/null 2>&1
        echo "tm: Transmission RPC not reachable at $host" >&2
        echo "tm: start the daemon/app, then try again." >&2
        return 1
    end

    set -l clip
    if test (count $argv) -gt 0
        set clip (string trim -- "$argv[1]")
    else
        set clip (pbpaste | string trim)
    end

    if test -z "$clip"
        echo "tm: clipboard is empty" >&2
        return 1
    end

    if not string match -rq '^magnet:\?' -- "$clip"
        echo "tm: not a magnet link" >&2
        return 1
    end

    if not string match -rq 'xt=urn:btih:' -- "$clip"
        echo "tm: magnet missing xt=urn:btih:" >&2
        return 1
    end

    if transmission-remote "$host" -a "$clip"
        echo "Magnet added to Transmission."
        echo "Track progress at http://$host/transmission/web/ (may be unavailable under VPN)"
    end
end
