function runbook-sync --description 'Regenerate server/runbook-example.md from the real (gitignored) server/runbook.md'
    set -l dotfiles ~/.dotfiles
    set -l src $dotfiles/server/runbook.md
    set -l dst $dotfiles/server/runbook-example.md

    if not test -f $src
        echo "runbook-sync: $src not found" >&2
        return 1
    end

    # Server-internal identifiers with no equivalent fish env var (unlike
    # $HOMELAB below) — update these if they ever change on the server.
    set -l disk_uuid d477f156-a70d-4aba-ab3d-5fa6d194e982
    set -l magicdns_hostname centos.tail586311.ts.net

    begin
        head -n 1 $src
        echo
        echo '> This is a sanitized template. The real, filled-in runbook is `runbook.md`'
        echo '> (gitignored, not tracked) — copy this file to `runbook.md` and replace the'
        echo '> `<placeholder>` values (Tailscale IP, MagicDNS hostname, disk UUID, local'
        echo '> username) with real ones.'
        echo
        tail -n +3 $src
    end \
        | string replace -a -- "$HOMELAB" '<tailscale-ip>' \
        | string replace -a -- "$magicdns_hostname" '<hostname>.<tailnet-name>.ts.net' \
        | string replace -a -- "$disk_uuid" '<disk-uuid>' \
        | string replace -ra -- '\beli\b' '<user>' \
        > $dst

    echo "runbook-sync: regenerated $dst"
end
