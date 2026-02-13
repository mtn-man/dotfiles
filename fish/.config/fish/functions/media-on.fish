function media-on --description 'Bring up Tailscale and mount homelab media share'
    # 1. Bring down Transmission so torrents don't leak from VPN
    if command -q brew
        brew services stop transmission-cli >/dev/null 2>&1
    end

    # 2. Ensure NordVPN is disconnected to prevent routing conflicts
    if functions -q nord-down
        nord-down
    end

    # 3. Ensure required commands exist
    for cmd in tailscale nc osascript diskutil
        if not command -q $cmd
            echo "media-on: required command '$cmd' not found in PATH; aborting." >&2
            return 127
        end
    end

    # 4. Ensure Tailscale is up (no-op if already connected)
    if not tailscale status >/dev/null 2>&1
        if not tailscale up >/dev/null 2>&1
            echo "media-on: tailscale up failed; attempting verbose output:" >&2
            tailscale up 2>&1 | sed 's/^/  /' >&2
            return 1
        end
        echo "media-on: Tailscale started..."
    end

    # 5. Wait until we can actually reach the SMB server over Tailscale
    set -l host 100.106.45.25
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
        echo "media-on: media share mounted at /Volumes/media"
        return 0
    else
        echo "media-on: mount command ran, but /Volumes/media not found" >&2
        return 1
    end
end
