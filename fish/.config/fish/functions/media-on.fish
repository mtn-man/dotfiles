function media-on --description 'Bring up Tailscale and mount homelab media share'
    # 0. Ensure NordVPN is disconnected to prevent routing conflicts
    tm-off
    nord-down
    # 1. Ensure Tailscale is up (no-op if already connected)
    if not command -q tailscale
        echo "media-on: tailscale not found in PATH" >&2
        return 127
    end

    # If status fails, try to bring it up.
    # Keep it quiet on success, but show errors on failure.
    if not tailscale status >/dev/null 2>&1
        if not tailscale up >/dev/null
            echo "media-on: tailscale up failed:" >&2
            tailscale up 2>&1 | sed 's/^/  /' >&2
            return 1
        end
        echo "media-on: Tailscale started..."
    end

    # 2. Wait until we can actually reach the server over Tailscale
    set -l host 100.106.45.25
    set -l tries 0
    set -l max_tries 10

    while test $tries -lt $max_tries
        if ping -c1 -W500 $host >/dev/null 2>&1
            break
        end
        sleep 0.5
        set tries (math $tries + 1)
    end

    if test $tries -ge $max_tries
        echo "media-on: Tailscale or $host not reachable; aborting mount" >&2
        echo "media-on: tailscale status:" >&2
        tailscale status 2>&1 | sed 's/^/  /' >&2
        return 1
    end

    # 3. Ask Finder to mount the share (uses Keychain creds if saved)
    #    Suppress AppleScript's "file media" result on success
    if not osascript -e 'mount volume "smb://100.106.45.25/media"' >/dev/null 2>&1
        echo "media-on: mount request failed (osascript returned non-zero)" >&2
        return 1
    end

    # 4. Friendly success / failure message
    if test -d /Volumes/media
        echo "media-on: media share mounted at /Volumes/media"
    else
        echo "media-on: mount command ran, but /Volumes/media not found" >&2
        return 1
    end
end
