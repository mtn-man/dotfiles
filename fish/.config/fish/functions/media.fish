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

function __media_run_with_timeout --argument-names timeout
    set -l cmd $argv[2..-1]
    set -l interval 0.5
    $cmd >/dev/null 2>&1 &
    set -l pid $last_pid
    set -l waited 0
    while math -q "$waited < $timeout"
        if not kill -0 $pid 2>/dev/null
            wait $pid 2>/dev/null
            return $status
        end
        sleep $interval
        set waited (math "$waited + $interval")
    end
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    return 1
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
            #    a hard wall-clock deadline via background job.
            set -l smb_port 445
            set -l smb_retries 5
            set -l nc_timeout 2
            set -l probe_budget 3
            set -l mount_timeout 10

            set -l smb_ok 0
            for _i in (seq $smb_retries)
                if __media_run_with_timeout $probe_budget \
                        nc -z -w $nc_timeout $HOMELAB_HOST $smb_port
                    set smb_ok 1
                    break
                end
            end
            if test $smb_ok -eq 0
                echo "media: server unreachable" >&2
                __media_rollback $__done
                return 1
            end

            # 5. Mount volume via Finder to utilize Keychain credentials
            if not __media_run_with_timeout $mount_timeout \
                    osascript -e "tell application \"Finder\" to mount volume \"$smb_url\""
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
            set -l tx_state (brew services info transmission-cli --json 2>/dev/null \
                | jq -r '.[0].status')
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
