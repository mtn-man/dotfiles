function media-off --description 'Unmount media share, disconnect Tailscale, connect NordVPN, and resume transmission daemon'
    # 1. Attempt to unmount the share
    if test -d /Volumes/media
        if diskutil unmount "/Volumes/media" >/dev/null 2>&1
            echo "media-off: media unmounted from /Volumes/media"
        else
            echo "media-off: failed to unmount /Volumes/media (disk may be busy)" >&2
            echo "media-off: diskutil says:" >&2
            diskutil unmount "/Volumes/media" 2>&1 | sed 's/^/  /' >&2
            return 1
        end
    else
        echo "media-off: /Volumes/media is not mounted"
    end

    # 2. Disconnect Tailscale (quiet on success, critical on failure)
    if not command -q tailscale
        echo "media-off: required command 'tailscale' not found in PATH; aborting." >&2
        return 127
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

    # 3. Connect NordVPN (required)
    if not functions -q nord-up
        echo "media-off: nord-up function not found; aborting." >&2
        return 127
    end

    nord-up; or begin
        echo "media-off: nord-up failed; not restarting transmission-cli" >&2
        return 1
    end

    # 4. Restart Transmission Service
    if not command -q brew
        echo "media-off: required command 'brew' not found in PATH; aborting." >&2
        return 127
    end
        
    brew services start transmission-cli >/dev/null; or begin
        echo "media-off: failed to start transmission-cli via brew" >&2
        return 1
    end
    echo "media-off: transmission-cli started @ http://localhost:9091/transmission/web/"
end
