function __media_fail
    echo "media: error: $argv[1]" >&2
    if set -q argv[2]
        string indent --n 2 -- "$argv[2]" >&2
    end
    return 1
end

function __media_require
    for cmd in $argv
        if not command -q $cmd
            echo "media: required command '$cmd' not found in PATH" >&2
            return 127
        end
    end
end

function __media_preflight --description 'Validate media command dependencies by mode'
    switch "$argv[1]"
        case on
            __media_require brew tailscale nc osascript jq; or return
        case off
            __media_require brew tailscale; or return
        case status
            __media_require brew; or return
        case '*'
            __media_fail "usage: __media_preflight [on|off]"; or return
    end
end

function media --description 'Manage homelab media share and networking state'
    set -l host "centos.tail586311.ts.net"
    set -l share "media"
    set -l mountpoint "/Volumes/$share"
    set -l smb_url "smb://$host/$share"

    switch "$argv[1]"
        case on
            # 1. Preflight dependency checks (fail fast before mutating state)
            __media_preflight on; or return

            # 2. Stop Transmission to prevent traffic leaks during network transition
            brew services stop transmission-cli >/dev/null; and echo "media: transmission-daemon stopped"; or __media_fail "failed to stop transmission-cli via brew"; or return

            # 3. Toggle VPN (NordVPN must be off for Tailscale/SMB routing)
            if not functions -q vpn; or not vpn off
                __media_fail "vpn management failed; aborting to avoid routing conflicts"; or return
            end

            # 4. Ensure Tailscale backend is active
            set -l state (tailscale status --json 2>/dev/null | jq -r .BackendState)
            if test "$state" != "Running"
                set -l ts_up_out (tailscale up 2>&1)
                if test $status -ne 0
                    __media_fail "tailscale up failed" "$ts_up_out"; or return
                end
                echo "media: Tailscale started"
            end

            # 5. Wait for SMB availability on the Tailscale network
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
            set -l os_out (osascript -e "tell application \"Finder\" to mount volume \"$smb_url\"" 2>&1)
            if test $status -ne 0
                __media_fail "mount request failed" "$os_out"; or return
            end

            test -d "$mountpoint"; and echo "media: mounted at $mountpoint"; or __media_fail "$mountpoint not found after mount command"

        case off
            # 1. Preflight dependency checks (fail fast before mutating state)
            __media_preflight off; or return

            # 2. Unmount the share and verify it is no longer in the filesystem
            if test -d "$mountpoint"
                set -l unmount_out (diskutil unmount "$mountpoint" 2>&1)
                if test $status -eq 0
                    echo "media: unmounted"
                else
                    __media_fail "failed to unmount $mountpoint (disk busy)" "$unmount_out"; or return
                end
            end

            # 3. Shut down Tailscale interface
            tailscale down >/dev/null 2>&1; and echo "media: Tailscale disconnected"
            or __media_fail "tailscale down failed" "$(tailscale status 2>&1)"; or return

            # 4. Re-enable VPN to secure subsequent torrent traffic
            if not functions -q vpn; or not vpn on
                __media_fail "vpn reconnect failed; not restarting transmission"; or return
            end

            # 5. Restart Transmission service
            brew services start transmission-cli >/dev/null; and echo "media: transmission-daemon resumed"
            or __media_fail "failed to restart transmission-cli"
        case status
            __media_preflight status; or return
        
            # SMB mount
            if test -d "$mountpoint"
                echo "media: $share is mounted at $mountpoint"
            else
                echo "media: $share is not mounted"
            end
        
            # VPN state
            if functions -q vpn
                vpn status
            else
                echo "media: vpn function not available" >&2
            end
        
            # Transmission service state
            set -l tx_state (brew services info transmission-cli --json 2>/dev/null | jq -r '.[0].status')
            if test -n "$tx_state"
                echo "media: transmission-daemon is $tx_state"
            else
                echo "media: could not determine transmission-cli state" >&2
            end
        case '*'
            echo "Usage: media [on|off]" >&2
            return 1
    end
end
