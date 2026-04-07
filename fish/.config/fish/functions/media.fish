function __media_rollback --description 'Undo completed media-on steps in reverse order'
# Policy: system default is VPN on + transmission active.
# Rollback enforces this baseline rather than restoring prior state.
    echo "media: rolling back..."
    for step in $argv
        switch $step
            case tailscale
                tailscale down >/dev/null 2>&1
            case vpn
                vpn on >/dev/null 2>&1
            case transmission
                brew services start transmission-cli >/dev/null 2>&1
        end
    end
end

function __media_vpn --argument-names subcmd
    vpn $subcmd 2>&1 | string replace --regex '^vpn:' 'media:'
    return $pipestatus[1]
end

function media --description 'Manage homelab media share and networking state'
    set -l mountpoint "/Volumes/$MEDIA_SHARE"
    set -l smb_url "smb://$HOMELAB_HOST/$MEDIA_SHARE"

    switch "$argv[1]"
        case on
            set -l __done

            # 1. Stop Transmission to prevent traffic leaks during network transition
            if brew services stop transmission-cli >/dev/null 2>&1
                echo "media: transmission-daemon stopped"
                set -p __done transmission
            else
                echo "media: error: failed to stop transmission-cli" >&2
                __media_rollback $__done
                return 1
            end

            # 2. Toggle VPN (NordVPN must be off for Tailscale/SMB routing)
            if not __media_vpn off
                __media_rollback $__done
                return 1
            end
            set -p __done vpn

            # 3. Ensure Tailscale backend is active
            set -l state (tailscale status --json 2>/dev/null | jq -r .BackendState)
            if test "$state" != "Running"
                if not tailscale up 2>/dev/null
                    echo "media: error: tailscale up failed" >&2
                    __media_rollback $__done
                    return 1
                end
                echo "media: Tailscale started"
            end
            set -p __done tailscale

            # 4. Wait for SMB availability on the Tailscale network
            #    nc -w is unreliable on macOS when DNS blocks, so enforce
            #    a hard 15-second wall-clock deadline via background job.
            set -l smb_ok 0
            set -l tries 0
            while test $tries -lt 5
                nc -z -w2 $HOMELAB_HOST 445 >/dev/null 2>&1 &
                set -l nc_pid $last_pid
                set -l waited 0
                while test $waited -lt 3
                    if not kill -0 $nc_pid 2>/dev/null
                        wait $nc_pid 2>/dev/null; and set smb_ok 1
                        break
                    end
                    sleep 0.5
                    set waited (math "$waited + 0.5")
                end
                kill $nc_pid 2>/dev/null; wait $nc_pid 2>/dev/null
                test $smb_ok -eq 1; and break
                set tries (math $tries + 1)
            end
            if test $smb_ok -eq 0
                echo "media: server unreachable" >&2
                __media_rollback $__done
                return 1
            end

            # 5. Mount volume via Finder to utilize Keychain credentials
            if not osascript -e "tell application \"Finder\" to mount volume \"$smb_url\"" >/dev/null 2>&1
                echo "media: error: mount request failed" >&2
                __media_rollback $__done
                return 1
            end

            if test -d "$mountpoint"
                echo "media: mounted at $mountpoint"
            else
                echo "media: error: $mountpoint not found after mount command" >&2
                __media_rollback $__done
                return 1
            end

        case off
            # 1. Unmount the share
            if test -d "$mountpoint"
                if diskutil unmount "$mountpoint" >/dev/null 2>&1
                    echo "media: unmounted"
                else
                    echo "media: error: failed to unmount $mountpoint (disk busy)" >&2
                    return 1
                end
            else
                echo "media: $MEDIA_SHARE is not mounted, skipping"
            end

            # 2. Shut down Tailscale interface
            if not tailscale down >/dev/null 2>&1
                echo "media: error: tailscale down failed" >&2
                return 1
            end
            echo "media: Tailscale disconnected"

            # 3. Re-enable VPN to secure subsequent torrent traffic
            if not __media_vpn on
                return 1
            end

            # 4. Restart Transmission service
            if brew services start transmission-cli >/dev/null 2>&1
                echo "media: transmission-daemon resumed"
            else
                echo "media: error: failed to restart transmission-cli" >&2
                return 1
            end

        case status
            # SMB mount
            if test -d "$mountpoint"
                echo "media: $MEDIA_SHARE is mounted at $mountpoint"
            else
                echo "media: $MEDIA_SHARE is not mounted"
            end

            # VPN state
            __media_vpn status

            # Transmission service state
            set -l tx_state (brew services info transmission-cli --json 2>/dev/null | jq -r '.[0].status')
            switch "$tx_state"
                case started
                    echo "media: transmission-daemon is on"
                case none
                    echo "media: transmission-daemon is off"
                case '*'
                    echo "media: transmission-daemon state unknown: $tx_state" >&2
            end

        case '*'
            echo "Usage: media [on|off|status]" >&2
            return 1
    end
end
