function __media_vpn --argument-names subcmd
    vpn $subcmd 2>&1 | string replace --regex '^vpn:' 'media:'
    return $pipestatus[1]
end

function __media_smb_reachable --argument-names host
    set -l retries 5
    set -l probe_budget 3
    set -l nc_timeout 2
    for _i in (seq $retries)
        if __media_run_with_timeout $probe_budget nc -z -w $nc_timeout $host 445
            return 0
        end
    end
    return 1
end

function __media_run_with_timeout --argument-names timeout
    set -l cmd $argv[2..-1]
    set -l interval 0.5
    $cmd >/dev/null 2>&1 &
    set -l pid $last_pid
    for _i in (seq (math --scale=0 "$timeout / $interval"))
        if not kill -0 $pid 2>/dev/null
            wait $pid 2>/dev/null
            return $status
        end
        sleep $interval
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
            # 1. Stop Transmission to prevent traffic leaks during network transition
            set -l tx_state (brew services info transmission-cli --json 2>/dev/null | jq -r '.[0].status')
            if test "$tx_state" = started
                if brew services stop transmission-cli >/dev/null 2>&1
                    echo "media: transmission-daemon stopped"
                else
                    echo "media: error: failed to stop transmission-cli" >&2
                    return 1
                end
            end

            # 2. Toggle VPN (NordVPN must be off for Tailscale/SMB routing)
            if not __media_vpn off
                echo "media: error: run 'vpn on' and 'tm on' to restore baseline" >&2
                return 1
            end

            # 3. Ensure Tailscale backend is active
            set -l state (tailscale status --json 2>/dev/null | jq -r .BackendState)
            if test "$state" != "Running"
                if not tailscale up 2>/dev/null
                    echo "media: error: tailscale up failed — run 'vpn on' and 'tm on' to restore baseline" >&2
                    return 1
                end
                echo "media: Tailscale started"
            end

            # 4. Wait for SMB availability on the Tailscale network
            #    nc -w is unreliable on macOS when DNS blocks, so enforce
            #    a hard wall-clock deadline via background job.
            set -l mount_timeout 10

            if not __media_smb_reachable $HOMELAB_HOST
                echo "media: error: server unreachable — run 'vpn on' and 'tm on' to restore baseline" >&2
                return 1
            end

            # 5. Mount volume via Finder to utilize Keychain credentials
            if not __media_run_with_timeout $mount_timeout \
                    osascript -e "tell application \"Finder\" to mount volume \"$smb_url\""
                echo "media: error: mount request failed — run 'vpn on' and 'tm on' to restore baseline" >&2
                return 1
            end

            if test -d "$mountpoint"
                echo "media: mounted at $mountpoint"
            else
                echo "media: error: $mountpoint not found after mount command — run 'vpn on' and 'tm on' to restore baseline" >&2
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
                echo "media: error: tailscale down failed — run 'tailscale down && vpn on' to restore baseline" >&2
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

        case '*'
            echo "Usage: media [on|off]" >&2
            return 1
    end
end
