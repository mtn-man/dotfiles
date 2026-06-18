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
    if not command -q jq
        echo "media: jq is required but not found" >&2
        return 127
    end

    argparse 'l/local' -- $argv

    set -l mountpoint "/Volumes/$MEDIA_SHARE"
    set -l host $HOMELAB
    if set -q _flag_local
        set host $HOMELAB_LOCAL
    end
    set -l smb_url "smb://$host/$MEDIA_SHARE"

    switch "$argv[1]"
        case on
            if not set -q _flag_local
                # Verify Tailscale is up — required to reach the homelab over the VPN
                set -l ts_state (tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null)
                if test "$ts_state" != Running
                    echo "media: error: tailscale is not up — connect via GUI before mounting" >&2
                    return 1
                end
            end

            if not __media_smb_reachable $host
                echo "media: error: server unreachable" >&2
                return 1
            end

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

        case '*'
            echo "Usage: media [on [-l/--local]|off]" >&2
            return 1
    end
end
