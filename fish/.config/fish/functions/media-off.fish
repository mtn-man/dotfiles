function media-off --description 'Unmount homelab media share, stop Tailscale, and start NordVPN'
    # 1. Attempt to unmount the share
    if test -d /Volumes/media
        if diskutil unmount "/Volumes/media" >/dev/null 2>&1
            echo "media-off: media share unmounted from /Volumes/media"
        else
            echo "media-off: failed to unmount /Volumes/media (disk may be busy)" >&2
            echo "media-off: diskutil says:" >&2
            diskutil unmount "/Volumes/media" 2>&1 | sed 's/^/  /' >&2
            return 1
        end
    else
        echo "media-off: /Volumes/media is not mounted"
    end

    # 2. Disconnect Tailscale (quiet on success, verbose on failure)
    if not command -q tailscale
        echo "media-off: tailscale not found in PATH; skipping tailscale down" >&2
        nord-up
        return 0
    end

    if tailscale down >/dev/null 2>&1
        echo "media-off: Tailscale disconnected"
    else
        echo "media-off: tailscale down failed:" >&2
        tailscale down 2>&1 | sed 's/^/  /' >&2
        echo "media-off: tailscale status:" >&2
        tailscale status 2>&1 | sed 's/^/  /' >&2
        return 1
    end

    # 3. Trigger NordVPN on success
    nord-up

    # 4. Retart Transmission Service
    tm-on
end
