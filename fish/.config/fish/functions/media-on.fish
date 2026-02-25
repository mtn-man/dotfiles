function media-on --description 'Stop transmission-cli, disconnect NordVPN, ensure Tailscale is running, then mount homelab media share'
    # 1. Bring down Transmission so torrent traffic doesn't leak outside VPN
    if command -q brew
        brew services stop transmission-cli >/dev/null && echo "media-on: transmission-daemon stopped"; or begin
            echo "media-on: failed to stop transmission-cli via brew; aborting." >&2
            return 1
        end
    else
        echo "media-on: required command 'brew' not found in PATH; aborting." >&2
        return 127
    end

    # 2. NordVPN must disconnect to prevent routing conflicts
    if not functions -q vpn-off
        echo "media-on: vpn-off function not found; aborting." >&2
        return 127
    end

    vpn-off; or begin
        echo "media-on: vpn-off failed; aborting to avoid routing conflicts." >&2
        return 1
    end

    # 3. Ensure required commands exist or exit
    for cmd in tailscale nc osascript jq
        if not command -q $cmd
            echo "media-on: required command '$cmd' not found in PATH; aborting." >&2
            return 127
        end
    end

    # 4. Ensure Tailscale is up (check BackendState via JSON for accuracy)
    set -l state (tailscale status --json 2>/dev/null | jq -r .BackendState)

    if test "$state" = "Running"
        echo "media-on: Tailscale already connected"
    else
        if not tailscale up >/dev/null 2>&1
            echo "media-on: tailscale up failed; attempting verbose output:" >&2
            tailscale up 2>&1 | sed 's/^/  /' >&2
            return 1
        end
        echo "media-on: Tailscale started"
    end

    # 5. Wait until we can actually reach the SMB server over Tailscale
    set -l host centos.tail586311.ts.net
    set -l tries 0
    set -l max_tries 10

    while test $tries -lt $max_tries
        if nc -z -w2 $host 445 >/dev/null 2>&1
            break
        end
        sleep 0.5
        set tries (math $tries + 1)
    end

    if test $tries -ge $max_tries
        echo "media-on: Tailscale or $host not reachable on SMB port; aborting mount" >&2
        echo "media-on: tailscale status:" >&2
        tailscale status 2>&1 | sed 's/^/  /' >&2
        return 1
    end

    # 6. Ask Finder to mount the share (uses Keychain creds if saved)
    # Build AppleScript with double quotes so fish expands $host reliably.
    set -l applescript "tell application \"Finder\" to mount volume \"smb://$host/media\""

    # Run osascript and capture stderr for diagnostics; keep quiet on success.
    set -l os_out (osascript -e "$applescript" 2>&1)
    set -l os_rc $status

    if test $os_rc -ne 0
        echo "media-on: mount request failed (osascript returned non-zero)." >&2
        if test -n "$os_out"
            echo "media-on: osascript output:" >&2
            echo "$os_out" | sed 's/^/  /' >&2
        end
        return 1
    end

    # 7. Friendly success / failure message
    if test -d /Volumes/media
        echo "media-on: media mounted at /Volumes/media"
        return 0
    else
        echo "media-on: mount command ran, but /Volumes/media not found" >&2
        return 1
    end
end
