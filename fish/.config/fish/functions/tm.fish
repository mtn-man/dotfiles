function tm --description 'Manage Transmission-CLI services and magnet links'
    set -l host "127.0.0.1:9091"
    set -l rpc_user "user"

    # 1. Check if the first argument is a service management subcommand
    if contains -- "$argv[1]" on off re restart ping
        if not command -q brew
            echo "tm: brew not found" >&2
            return 127
        end
    end

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
    end

    # 2. All remaining commands need transmission-remote and keychain credentials
    if not command -q transmission-remote
        echo "tm: transmission-remote not found (brew install transmission-cli)" >&2
        return 127
    end

    set -l pass (security find-generic-password -s transmission-rpc -a $rpc_user -w 2>/dev/null)
    if test -z "$pass"
        echo "tm: credentials not found in keychain" >&2
        echo "tm: run: security add-generic-password -s transmission-rpc -a $rpc_user -w" >&2
        return 1
    end

    switch "$argv[1]"
        case ping
            transmission-remote "$host" -n "$rpc_user:$pass" -st
            return
    end

    # Preflight: ensure Transmission daemon is running and RPC is reachable
    if not transmission-remote "$host" -n "$rpc_user:$pass" -l >/dev/null 2>&1
        echo "tm: Transmission RPC not reachable at $host" >&2
        echo "tm: start the daemon/app, then try again." >&2
        return 1
    end

    set -l input
    if set -q argv[1]
        set input (string trim -- "$argv[1]")
    else
        set input (pbpaste | string trim)
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
        if transmission-remote "$host" -n "$rpc_user:$pass" -a "$input"
            echo "tm: torrent added"
            echo "Track progress at http://$host/transmission/web/"
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

    if transmission-remote "$host" -n "$rpc_user:$pass" -a "$input"
        echo "Magnet added to Transmission."
        echo "Track progress at http://$host/transmission/web/"
    end
end
