function media-on --description 'Bring up Tailscale and mount homelab media share'
    # 0. Ensure NordVPN is disconnected to prevent routing conflicts
    nord-down

    # 1. Ensure Tailscale is up (no-op if already connected)
    if command -q tailscale
        # Try a quick status; if it fails, bring it up
        tailscale status >/dev/null 2>&1
        or tailscale up >/dev/null 2>&1
    end

    # 2. Wait until we can actually reach the server over Tailscale
    #    (short, bounded loop instead of a fixed sleep)
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
        echo "media-on: Tailscale or $host not reachable; aborting mount"
        return 1
    end

    # 3. Ask Finder to mount the share (uses Keychain creds if saved)
    #    Suppress AppleScript's "file media" result on success
    osascript -e 'mount volume "smb://100.106.45.25/media"' >/dev/null 2>&1

    # 4. Friendly success / failure message
    if test -d /Volumes/media
        echo "media-on: media share mounted at /Volumes/media"
    else
        echo "media-on: mount command ran, but /Volumes/media not found"
        return 1
    end
end
