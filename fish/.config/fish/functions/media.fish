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
    argparse 'l/local' -- $argv

    set -l mountpoint "/Volumes/$MEDIA_SHARE"
    set -l host $HOMELAB_HOST
    if set -q _flag_local
        set host $HOMELAB_HOST_LOCAL
    end
    set -l smb_url "smb://$host/$MEDIA_SHARE"

    switch "$argv[1]"
        case on
            if not set -q _flag_local
                # Enforce Tailscale mode: VPN down + Tailscale up
                if not __media_vpn off
                    echo "media: error: failed to enter tailscale mode" >&2
                    return 1
                end
            end

            # Wait for SMB availability
            #    nc -w is unreliable on macOS when DNS blocks, so enforce
            #    a hard wall-clock deadline via background job.
            if not __media_smb_reachable $host
                echo "media: error: server unreachable" >&2
                return 1
            end

            # Mount volume via Finder to utilize Keychain credentials
            set -l mount_timeout 10
            if not __media_run_with_timeout $mount_timeout \
                    osascript -e "tell application \"Finder\" to mount volume \"$smb_url\""
                echo "media: error: mount request failed" >&2
                return 1
            end

            if test -d "$mountpoint"
                echo "media: mounted at $mountpoint"
            else
                echo "media: error: $mountpoint not found after mount command" >&2
                return 1
            end

        case off
            # Unmount the share
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

            # Enforce VPN mode: Tailscale down + VPN up
            if not __media_vpn on
                echo "media: error: failed to enter vpn mode — run 'vpn on' manually" >&2
                return 1
            end

        case '*'
            echo "Usage: media [on [-l/--local]|off]" >&2
            return 1
    end
end
