function media-off --description 'Unmount homelab media share, stop Tailscale, and start NordVPN'
    # 1. Attempt to unmount the share
    if test -d /Volumes/media
        if diskutil unmount "/Volumes/media" >/dev/null 2>&1
            echo "media-off: media share unmounted from /Volumes/media"
        else
            echo "media-off: failed to unmount /Volumes/media (disk may be busy)"
            return 1
        end
    else
        echo "media-off: /Volumes/media is not mounted"
    end

    # 2. Disconnect Tailscale
    if command -q tailscale
        if tailscale down >/dev/null 2>&1
            echo "media-off: Tailscale disconnected"
            
            # 3. Trigger NordVPN on success
            nord-up
        else
            echo "media-off: Failed to disconnect Tailscale"
            return 1
        end
    else
        # If Tailscale is not found, proceed to NordVPN as a fallback
        nord-up
    end
end
