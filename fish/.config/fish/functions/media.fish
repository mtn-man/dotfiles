function media --description 'Manage homelab media share and networking state'
    switch "$argv[1]"
        case on
            # 1. Stop Transmission to prevent traffic leaks during network transition
            __media_require brew; or return
            brew services stop transmission-cli >/dev/null; and echo "media: transmission-daemon stopped"; or __media_fail "failed to stop transmission-cli via brew"; or return

            # 2. Toggle VPN (NordVPN must be off for Tailscale/SMB routing)
            if not functions -q vpn; or not vpn off
                __media_fail "vpn management failed; aborting to avoid routing conflicts"; or return
            end

            # 3. Verify networking dependencies
            __media_require tailscale nc osascript jq; or return

            # 4. Ensure Tailscale backend is active
            set -l state (tailscale status --json 2>/dev/null | jq -r .BackendState)
            if test "$state" != "Running"
                tailscale up >/dev/null 2>&1; or __media_fail "tailscale up failed" "$(tailscale up 2>&1)"; or return
                echo "media: Tailscale started"
            end

            # 5. Wait for SMB availability on the Tailscale network
            set -l host centos.tail586311.ts.net
            set -l tries 0
            while test $tries -lt 10
                nc -z -w2 $host 445 >/dev/null 2>&1; and break
                sleep 0.5
                set tries (math $tries + 1)
            end
            if test $tries -ge 10
                __media_fail "$host not reachable on SMB port" "$(tailscale status 2>&1)"; or return
            end

            # 6. Mount volume via Finder to utilize Keychain credentials
            set -l os_out (osascript -e "tell application \"Finder\" to mount volume \"smb://$host/media\"" 2>&1)
            if test $status -ne 0
                __media_fail "mount request failed" "$os_out"; or return
            end

            test -d /Volumes/media; and echo "media: mounted at /Volumes/media"; or __media_fail "/Volumes/media not found after mount command"

        case off
            # 1. Unmount the share and verify it is no longer in the filesystem
            if test -d /Volumes/media
                diskutil unmount "/Volumes/media" >/dev/null 2>&1; and echo "media: unmounted"
                or __media_fail "failed to unmount /Volumes/media (disk busy)" "$(diskutil unmount "/Volumes/media" 2>&1)"; or return
            end

            # 2. Shut down Tailscale interface
            __media_require tailscale; or return
            tailscale down >/dev/null 2>&1; and echo "media: Tailscale disconnected"
            or __media_fail "tailscale down failed" "$(tailscale status 2>&1)"; or return

            # 3. Re-enable VPN to secure subsequent torrent traffic
            if not functions -q vpn; or not vpn on
                __media_fail "vpn reconnect failed; not restarting transmission"; or return
            end

            # 4. Restart Transmission service
            __media_require brew; or return
            brew services start transmission-cli >/dev/null; and echo "media: transmission-daemon resumed"
            or __media_fail "failed to restart transmission-cli"

        case '*'
            echo "Usage: media [on|off]" >&2
            return 1
    end
end
