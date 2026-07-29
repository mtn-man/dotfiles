# Media Server Runbook (CentOS Stream 10)

## 1. Purpose and Scope

This system is a single-node media server intended for family and friends use.

Primary goals:
- Reliability over performance
- Predictable behavior after unexpected restarts
- Simple recovery from failure
- Minimal ongoing maintenance

Non-goals:
- High availability
- Redundancy across nodes
- Zero-downtime upgrades

Downtime of several hours is acceptable. Data loss is not acceptable.

---

## 2. System Overview

**Host**
- CentOS Stream 10
- Intel N150 (low power mini PC)
- 8 GiB RAM
- SELinux enabled

**Primary Services**
- Jellyfin (Podman container, systemd-managed)
- Transmission-Remote (bound to VPN connection)
- SMB file sharing
- SSH access

**Remote Access**
- Tailscale only
- No public internet exposure
- No reverse proxy

---

## 3. Power and Boot Model

- System runs always-on
- Power cuts are unplanned (upstream outages only)
- System boots automatically after power is restored

Design assumption:
- USB storage may take significant time to spin up and enumerate after an unplanned power cut

Mitigation:
- Jellyfin startup is explicitly tied to storage availability
- Jellyfin will not start until storage is mounted
- Jellyfin will stop if storage disappears

---

## 4. Storage Layout

| Path | Purpose | Notes |
|-----|--------|-------|
| `/` | OS | XFS |
| `/home` | User data | XFS |
| `/mnt/storage` | Media library | XFS, USB-attached |
| `/mnt/storage/Movies` | Processed movies | mintmedia destination |
| `/mnt/storage/Shows` | Processed TV shows | mintmedia destination |
| `/mnt/storage/Downloads` | Transmission download root | |
| `/mnt/storage/Downloads/complete` | Completed downloads; mintmedia watch folder | Default linuxserver/transmission layout |
| `/mnt/storage/Downloads/incomplete` | In-progress downloads | |
| `/var/lib/jellyfin/config` | Jellyfin configuration | Persistent |
| `/var/lib/jellyfin/cache` | Jellyfin cache | Persistent |
| `/var/lib/transmission/config` | Transmission configuration | Persistent |

**Storage Characteristics**
- USB dock does not pass full SMART data
- Drive temperature monitoring is available
- Weekly cold backups are maintained
- Full drive swap and restore has been tested

---

## 5. Jellyfin Service

**Service Type**
- systemd system service
- Podman-managed container

**Service File**
/etc/systemd/system/jellyfin.service

**Key Design Points**
- Requires `/mnt/storage` to be mounted
- Wait loop allows for slow USB disk spin-up after unplanned power cuts
- Manual container image updates only
- Container health check polls `/health` every 30s; kills container on 3 consecutive failures (systemd restarts it)

**Check the Service**
```sh
sudo systemctl status jellyfin.service
```

**Restart the Service**
```sh
sudo systemctl restart jellyfin.service
```

### HTTPS Access via Tailscale Serve

Jellyfin itself only serves plain HTTP on 8096. HTTPS is added externally by `tailscaled`, which terminates TLS on 443 using a Tailscale-issued (auto-renewing) cert for the node's MagicDNS name, and reverse-proxies to Jellyfin's existing HTTP port. `jellyfin.service` is not modified by this and HTTP access on 8096 continues to work unchanged.

Requires MagicDNS and HTTPS Certificates to be enabled for the tailnet in the Tailscale admin console.

**Enable (persist across reboots and terminal sessions)**
```bash
sudo tailscale serve --bg --https=443 http://localhost:8096
```

`--bg` is required — without it, the rule only stays active for the life of the foreground terminal session and is torn down as soon as it exits.

**Check status**
```bash
tailscale serve status
```

**Disable**
```bash
tailscale serve --https=443 off
```

**Result** — `https://centos.tail586311.ts.net` (tailnet-only, valid cert, no browser warning) alongside the existing `http://100.106.45.25:8096`.

### Public Internet Access via Tailscale Funnel

Funnel extends the `serve` rule above to the public internet (not just the tailnet), at the same hostname, so friends/family can connect without installing Tailscale. Gated behind the hardening checklist in `~/dev/server/jellyfin-funnel-checklist.md` (account lockout, permissions, resource caps, backup automation, kill switch) before being enabled.

**Enable**
```bash
sudo tailscale funnel --bg --https=443 http://localhost:8096
```

**Check status**
```bash
tailscale serve status
```

**Kill switch / disable** — pulls Jellyfin off the public internet immediately without touching tailnet access, for suspected compromise, abuse, or anything that looks wrong. This is the exact command `tailscale funnel` itself echoes back after enabling, confirmed live 2026-07-26:
```bash
sudo tailscale funnel --https=443 off
```
This clears only the funnel (public) config for port 443; it does not touch the `serve` rule above, so Jellyfin stays reachable over the tailnet exactly as it does today. (`sudo tailscale funnel reset` is a broader alternative that clears *all* funnel rules on the node, not just this one — prefer the scoped command above unless you specifically want that.) Note: the Tailscale CLI changed its serve/funnel syntax at some point after this runbook was first written — the old `tailscale funnel 443 off` shorthand no longer works. Verify against `tailscale funnel --help` if this ever looks stale again.

### Jellyfin Image Update Procedure

The Jellyfin service uses `--pull=never`, so a new image must be pulled explicitly before restarting. The image runs under the `eli` user account, so no `sudo` is needed for the pull.

**Steps**

1. Pull the latest image
```bash
podman pull docker.io/jellyfin/jellyfin:latest
```

2. Restart the service
```bash
sudo systemctl restart jellyfin.service
```

3. Verify the service is running
```bash
sudo systemctl status jellyfin.service
```

4. Verify Jellyfin UI loads — `http://100.106.45.25:8096` over Tailscale

5. Verify media playback and thumbnails

6. Remove the old dangling image
```bash
podman image prune
```

---

## 6. VPN + Transmission Service

**Service Type**
- Two systemd system services
- Podman-managed containers

**Service Files**
- `/etc/systemd/system/nordvpn.service`
- `/etc/systemd/system/transmission.service`

**Architecture**
- `nordvpn` container owns the network namespace and establishes the VPN tunnel
- `transmission` container shares the nordvpn network namespace
- All torrent peer traffic is routed through the NordVPN NordLynx (WireGuard) tunnel
- Transmission RPC is published exclusively to the Tailscale interface (`100.106.45.25:9091`)

**Key Design Points**
- Requires `/mnt/storage` to be mounted (inherited from nordvpn service)
- NordVPN kill switch is enabled -- torrent traffic stops if VPN drops
- Transmission will not start until VPN tunnel is confirmed connected
- Both services stop if storage disappears
- Leftover containers are force-removed on each start to handle unclean shutdowns
- Manual container image updates only

**Storage Paths**

| Path | Purpose |
|------|---------|
| `/var/lib/transmission/config` | Transmission configuration and settings |
| `/mnt/storage/Downloads` | Download root |
| `/mnt/storage/Downloads/complete` | Completed downloads (watched by mintmedia) |
| `/mnt/storage/Downloads/incomplete` | In-progress downloads |

**Authentication**
- NordVPN authenticates via an access token stored as a Podman secret (`nordvpn_token`)
- Token expires annually and must be regenerated from the NordVPN dashboard
- To regenerate: log in at `my.nordaccount.com` → Services → NordVPN → Set up NordVPN manually → Access token
- Update the secret:
```bash
sudo podman secret rm nordvpn_token
echo -n "new-token" | sudo podman secret create nordvpn_token -
sudo systemctl restart nordvpn.service
```

**SELinux**
- `/var/lib/transmission` and `/mnt/storage/Downloads` require `container_file_t` label
- Labels are applied via semanage policy and are persistent across relabels:
```bash
sudo semanage fcontext -a -t container_file_t '/var/lib/transmission(/.*)?'
sudo semanage fcontext -a -t container_file_t '/mnt/storage/Downloads(/.*)?'
```
- To reapply after a relabel:
```bash
sudo restorecon -Rv /var/lib/transmission /mnt/storage/Downloads
```

**Firewalld**
- Podman bridge subnet (`10.88.0.0/16`) is in the trusted zone
- Tailscale interface (`tailscale0`) is in the trusted zone
- NordVPN allowlist includes `10.88.0.0/16` and `100.64.0.0/10` (baked into container entrypoint)

### NordVPN Container Rebuild Procedure

This procedure updates the nordvpn client inside the container to the latest version available from NordVPN's apt repository. It is needed when upstream NordVPN changes cause connection failures, or as a proactive maintenance step.

**No changes to source files are required.** The Containerfile pulls the latest nordvpn package at build time.

**Note**: The Containerfile is `FROM ubuntu:24.04` — NordVPN's official Linux client only ships `.deb` packages, so the build uses an Ubuntu base rather than CentOS/Fedora. This means `podman images` will always show a cached `docker.io/library/ubuntu:24.04` image alongside the app containers; it's a build dependency for this procedure, not orphaned bloat.

**Steps**

1. Stop both services (Transmission depends on the nordvpn network namespace and must stop first)
```bash
sudo systemctl stop transmission.service
sudo systemctl stop nordvpn.service
```

2. Rebuild the image from the source directory
```bash
sudo podman build --no-cache -t localhost/nordvpn-custom:latest ~/nordvpn-image/
```
> `--no-cache` is required — without it Podman reuses cached layers and will not pull the latest NordVPN package from the apt repo.

3. Restart both services
```bash
sudo systemctl start nordvpn.service
sudo systemctl start transmission.service
```

4. Verify the VPN is connected
```bash
sudo podman exec nordvpn nordvpn status
```

5. Verify Transmission is running
```bash
sudo systemctl status transmission.service
```

**Notes**
- The Podman secret (`nordvpn_token`) is unaffected by rebuilds and does not need to be recreated
- The build requires outbound internet access to reach `repo.nordvpn.com`
- Build time is typically under a few minutes on the N150

---

### Transmission Image Update Procedure

The Transmission service uses `--pull=never` and runs rootful, so the pull requires `sudo`.

**Steps**

1. Stop Transmission (nordvpn can remain running)
```bash
sudo systemctl stop transmission.service
```

2. Pull the latest image
```bash
sudo podman pull docker.io/linuxserver/transmission:latest
```

3. Start Transmission
```bash
sudo systemctl start transmission.service
```

4. Verify the service is running
```bash
sudo systemctl status transmission.service
```

5. Verify torrent traffic is still using the VPN
```bash
sudo podman exec transmission netstat -tnp | grep 51413
```

6. Remove the old dangling image
```bash
sudo podman image prune
```

---

**Check the Services**
```bash
sudo systemctl status nordvpn.service
sudo systemctl status transmission.service
sudo podman exec nordvpn nordvpn status
```

**Restart the Services**
```bash
sudo systemctl restart nordvpn.service
sudo systemctl restart transmission.service
```

**Access Transmission**
- Web UI: `http://100.106.45.25:9091/transmission/` (Tailscale only)
- RPC endpoint: `http://100.106.45.25:9091/transmission/rpc`

---

## 7. mintmedia Service

**Purpose**
- Watches `/mnt/storage/Downloads/complete` for completed downloads
- Renames and moves media to `/mnt/storage/Movies` or `/mnt/storage/Shows`
- Monitors Transmission via RPC; auto-removes completed torrents after successful processing

**Service Type**
- systemd user service, running the mintmedia daemon directly (`Type=simple`)

**Service File**
`~/.config/systemd/user/mintmedia.service`

**Key Design Points**
- Runs as a user service under `eli`; linger is enabled so it starts at boot without login
- `Restart=on-failure` — systemd restarts the daemon automatically if it exits unexpectedly
- Built and updated manually from source at `~/dev/golang/mintmedia`
- Transmission integration connects to `100.106.45.25:9091` (Tailscale)
- `defer_destination_checks = true` — daemon starts even if `/mnt/storage` is not yet mounted; queues work until storage is available

**Check the Service**
```bash
systemctl --user status mintmedia.service
```

**Restart the Service**
```bash
systemctl --user restart mintmedia.service
```

**Configuration**
`~/.config/mintmedia/config.toml`

**Logs**
- stdout/stderr go to the journal. Use `--user-unit=`, not `--user -u` — this box has no split per-uid journal file (`user-1000.journal`), only `system.journal`, so the `--user` scope flag finds no files to search. `--user-unit=` matches the `_SYSTEMD_USER_UNIT` field directly against the system journal instead:
```bash
journalctl --user-unit=mintmedia.service          # full log
journalctl --user-unit=mintmedia.service -f       # follow live
journalctl --user-unit=mintmedia.service -n 100   # last 100 lines
```
- Reading the journal requires membership in the `systemd-journal` group (one-time): `sudo usermod -aG systemd-journal eli`, then re-login.
- Structured processing history: `~/.local/state/mintmedia/history.jsonl`

---

## 8. Devbox — Persistent Dev Container

**Purpose**
- Persistent, reproducible Alpine Linux container for long-running builds,
  coding agents, and other dev tasks that don't need to live on the Mac client
- Provides `git`, `gh`, Go, Rust, `tmux`, `lazygit`, and Claude Code, plus
  the shell tooling the Mac side already leans on (`ripgrep`, `fzf`, `bat`,
  `jq`, `eza`, `fd`) and Rust build essentials (`pkgconf`, `openssl-dev`,
  `python3`)
- `dev`'s login shell is `fish`; `bash` stays installed as a fallback

**Service Type**
- User-level Quadlet unit (rootless Podman), same tier as mintmedia — not a
  system service like Jellyfin

**Image Source**
`~/devbox-image/Containerfile` — no git checkout exists on the server
itself, so this is a manually-placed copy, same pattern as
`~/nordvpn-image/`. Canonical, version-controlled source is on the Mac at
`~/.dotfiles/server/devbox/Containerfile`.

**Quadlet Unit File**
`~/.config/containers/systemd/devbox.container` (canonical copy:
`~/.dotfiles/server/systemd/user/devbox.container`)

**Key Design Points**
- `HostName=devbox` and `ContainerName=devbox` — fixed name and hostname
- `UserNS=keep-id` maps the invoking host user's UID 1:1 into the container
  (rather than to root); the container's `dev` user is pinned to UID/GID
  1000 to match `eli`, so bind-mounted file ownership is transparent on
  both sides
- Workspace: the existing `~/dev` tree is bind-mounted straight through to
  `/home/dev/dev` rather than a separate directory — the same repos
  (including mintmedia's own source checkout) are reachable at the same
  path on host and in-container
- All `Volume=` mounts use the `:Z` SELinux relabel suffix — this host runs
  SELinux Enforcing, and without it the container (`container_t`) can't
  write to host paths labeled `user_home_t`
- No SSH client in the image (`openssh-client` deliberately omitted) — the
  access model is host SSH (Tailscale) + `podman exec` in from there, never
  SSH directly into the container itself, so an in-container SSH client
  serves no purpose here
- Tool state is split from the workspace and persisted separately, so
  logins/config survive a crash-restart: `~/devbox/state/{claude,claude.json,gh,lazygit}`
  and `~/devbox/state/git` (mounted at `~/.config/git`, not `~/.gitconfig`
  directly — git falls back to the XDG path when `~/.gitconfig` doesn't
  exist, which avoids a bind-mounted single file breaking tools that write
  config via temp-file-then-rename)
- `~/devbox/state/lazygit/config.yml` intentionally diverges from the
  Mac's tracked copy (`~/.dotfiles/lazygit/.config/lazygit/config.yml`):
  Alpine 3.23 ships `lazygit 0.48.0-r12`, which predates a v0.62.0 syntax
  rework, so the `confirmInEditor` keybinding uses the old `<a-enter>` form
  rather than the Mac's `<alt+enter>`. Don't sync the Mac's file over this
  one without translating the syntax again.
- The Containerfile explicitly pre-creates `/home/dev/.config` (owned
  `dev:dev`) before `USER dev`. Without this, Podman auto-creates it as a
  mount-parent directory (needed to attach `.config/gh` and `.config/git`)
  owned `root:dev` with no group-write bit, which silently blocks `dev`
  from creating any *other* entry directly under `~/.config` — this is how
  the `lazygit` persistence above was found to be broken initially. Any
  future bind mount under a not-yet-existing parent directory is at risk
  of the same problem.
- Shell configuration (`.bashrc`, `.vimrc`, `.tmux.conf`) is intentionally
  **not** persisted — it comes from the image, so it stays reproducible
  from the Containerfile. Like Jellyfin and Transmission, this container is
  recreated fresh from the image on every systemd restart; only
  `Volume=`-mounted paths survive
- `fish` is the one exception to that rule: `~/.config/fish` is bind-mounted
  straight from the host's own live fish config (`~/.dotfiles/server/fish`,
  sourced manually per the repo's CLAUDE.md) rather than baked into the
  Containerfile, so devbox's fish always matches whatever the host is
  running — no image rebuild needed to pick up a config change
- Resource ceiling: `MemoryMax=3G`, `CPUQuota=200%` — this is an 8 GiB N150
  box also running Jellyfin, NordVPN+Transmission, and mintmedia; a long
  build or an agent loop shouldn't be able to starve those

**Check the Service**
```sh
systemctl --user status devbox.service
podman ps
```

**Restart the Service**
```sh
systemctl --user restart devbox.service
```
Recreates the container fresh from the current image tag — anything
outside a `Volume=` mount is lost (see Key Design Points).

**Interactive Access**

A single tmux session lives on the host (`lab`), not inside the container.
The `devbox` fish function (`~/.config/fish/functions/devbox.fish`, sourced
from `server/fish/functions/devbox.fish` in dotfiles) creates it on first
use and just reattaches on every later call:
```fish
function devbox --description 'Attach to the persistent host-side tmux session, entering the devbox container on first use'
    tmux new-session -A -s devbox 'podman exec -it -w /home/dev/dev devbox fish'
end
```
`tmux new-session -A -s devbox` behaves like `attach-session` if `devbox`
already exists — in that case the `podman exec` argument is ignored and
you're dropped straight back into the running session, exactly as left.
Only on first creation does it actually run `podman exec -it -w
/home/dev/dev devbox fish`, landing in the bind-mounted `~/dev` workspace
inside the container. Detach with `Ctrl-b d` rather than exiting, to leave
it running.

**Entry points** — the Mac's `dev` abbr (`fish/.config/fish/abbrs.fish`) and
the `dev-raycast.sh` Raycast script both just run `ssh -t lab devbox`,
delegating the tmux logic to the host-side function above.

**Manual equivalent** (if the `devbox` function is ever unavailable):
```sh
ssh -t lab
tmux new-session -A -s devbox 'podman exec -it -w /home/dev/dev devbox fish'
```

**Resolved — Claude Code rendering inside tmux:** dynamic/special symbols
(box-drawing corners, logo glyphs) used to render as stray underscores when
`claude` ran inside the *container's own* tmux session, back when the
persistent session lived inside the container (`podman exec -it devbox
tmux new -As main`). Several candidates were ruled out at the time (tmux
synchronized-output support, `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN`,
Ghostty cursor style) without isolating a definitive cause. Since moving
the persistent tmux session to the host (see Interactive Access above —
`devbox` now wraps a plain `podman exec ... fish`, with no tmux running
inside the container at all), `claude` renders normally under the
`devbox` wrapper. This points to the bug being specific to tmux running
inside the Alpine container rather than tmux in general.

### Devbox Image Rebuild Procedure

Needed when adding or updating tooling in the Containerfile.

```sh
cd ~/devbox-image
podman build -t localhost/devbox:latest -f Containerfile .
systemctl --user restart devbox.service
```
Rebuilding with the same tag retags `localhost/devbox:latest` to the new
image; the previous image becomes dangling (untagged, not deleted). Clean
up periodically:
```sh
podman image prune
```

### Removing Devbox

Full teardown — service, image, build context, and persisted state:

```sh
systemctl --user stop devbox.service
rm ~/.config/containers/systemd/devbox.container
systemctl --user daemon-reload
podman rmi localhost/devbox:latest
podman image prune
rm -rf ~/devbox-image ~/devbox
```
Does **not** touch `~/dev` — that's the shared workspace (also home to
mintmedia's own source checkout), reused as-is rather than owned by devbox,
so it's left alone regardless of how thorough a teardown this is.

---

## 9. Networking and Access

**Access Model**
- Tailscale provides encrypted access
- No ports exposed to the public internet

**Services Accessible Over Tailscale**
- Jellyfin (HTTP on 8096, HTTPS on 443 via `tailscale serve` — see Section 5)
- SMB
- SSH

**Notes**
- Tailscale CGNAT ranges must NOT be listed as "Known Proxies" in Jellyfin
- Jellyfin LAN subnet includes the Tailscale address range

### Firewalld Zone Configuration

**`trusted` zone** — `tailscale0` interface, plus the Podman bridge subnet (`10.88.0.0/16`)
- `target: ACCEPT` — all traffic over the tailnet is allowed
- This is what actually grants Jellyfin/SSH/Samba access described above; no per-service rules are needed here

**`public` zone** — `enp1s0` (physical LAN interface)
- `services: cockpit dhcpv6-client`
- No ports open
- SSH, Samba, HTTP/HTTPS, and Jellyfin (main port, alt HTTPS port, and DLNA discovery ports 1900/udp + 7359/udp) are explicitly **not** exposed to the LAN — access to all of these is Tailscale-only, matching the stated access model
- Cockpit (port 9090) is the one intentional exception: kept reachable on the LAN for troubleshooting if Tailscale itself is ever down

**Known effect of this**
- Jellyfin client apps that rely on LAN auto-discovery (SSDP/DLNA broadcast) will no longer find the server automatically — clients must connect via the Tailscale address or the `tailscale serve` HTTPS URL directly

**Commands Used to Reach This State**

The `public` zone previously had `ssh samba http https` plus ports `8096/tcp 8920/tcp 1900/udp 7359/udp 8080/tcp` open — leftover from earlier manual `firewall-cmd --add-*` calls, exposing SSH/Samba/Jellyfin to the LAN in contradiction of the Tailscale-only access model. `8080/tcp` had no identifiable owner (nothing listening, no container/systemd/config reference, no shell history) and was removed as dead configuration.

```bash
sudo firewall-cmd --zone=public --remove-service=ssh --permanent
sudo firewall-cmd --zone=public --remove-service=samba --permanent
sudo firewall-cmd --zone=public --remove-service=http --permanent
sudo firewall-cmd --zone=public --remove-service=https --permanent
sudo firewall-cmd --zone=public --remove-port=8096/tcp --permanent
sudo firewall-cmd --zone=public --remove-port=8920/tcp --permanent
sudo firewall-cmd --zone=public --remove-port=1900/udp --permanent
sudo firewall-cmd --zone=public --remove-port=7359/udp --permanent
sudo firewall-cmd --zone=public --remove-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

`cockpit` and `dhcpv6-client` were left in place intentionally and required no changes.

**To verify current state**
```bash
sudo firewall-cmd --list-all --zone=public
sudo firewall-cmd --list-all --zone=trusted
```

### Cockpit HTTPS Access via Tailscale Serve

Cockpit terminates its own TLS on 9090 using a self-signed cert, which triggers a browser warning when accessed directly. `tailscale serve` adds a second, warning-free HTTPS path on port 8443, reusing the same pattern as Jellyfin (Section 5) but proxying to Cockpit's existing HTTPS backend instead of plain HTTP.

Port 8443 is used instead of 443 because Jellyfin already owns the root path on 443. The `https+insecure://` scheme skips backend cert validation on the tailscaled→Cockpit hop; this hop stays on loopback, so it does not weaken anything exposed on the tailnet.

**Enable (persist across reboots and terminal sessions)**
```bash
sudo tailscale serve --bg --https=8443 https+insecure://localhost:9090
```

**Check status**
```bash
tailscale serve status
```

**Disable**
```bash
tailscale serve --https=8443 off
```

**Result** — `https://centos.tail586311.ts.net:8443` (tailnet-only, valid cert, no browser warning), added *alongside* the existing direct access on `http://100.106.45.25:9090` and the LAN-only `public` zone exposure (Section 9, Firewalld Zone Configuration). The direct paths are left in place intentionally — they're the fallback if Tailscale itself is ever down.

---

### Tailscale Exit Node

The server is configured as a Tailscale exit node, routing client traffic through the server's internet connection.

**Enable Exit Node Advertising**

`tailscale up` requires all non-default flags to be stated together. `--ssh` was already set, so both flags must be included:

```bash
sudo tailscale up --advertise-exit-node --ssh
```

**Enable IPv4 Forwarding (persistent)**

Required for exit node routing. Without this, subnet routes and exit node traffic do not work:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```

**Fix UDP GRO Forwarding (persistent)**

Improves UDP throughput. Applied to `enp1s0` via a NetworkManager dispatcher script so it runs automatically when the interface comes up.

Create `/etc/NetworkManager/dispatcher.d/99-tailscale-udp-gro` with the following contents, then make it executable:

```bash
#!/bin/bash
if [ "$1" = "enp1s0" ] && [ "$2" = "up" ]; then
    ethtool -K enp1s0 rx-udp-gro-forwarding on rx-gro-list off
fi
```

```bash
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-tailscale-udp-gro
```

To verify without rebooting:
```bash
sudo /etc/NetworkManager/dispatcher.d/99-tailscale-udp-gro enp1s0 up
```

**Enable Masquerade on the Public Zone**

Required for exit node traffic to be NAT'd out through `enp1s0`. Without this, packets are forwarded but have no return path:

```bash
sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --reload
```

**Approve the Exit Node**

After running `tailscale up --advertise-exit-node`, the node must be approved in the Tailscale admin console before clients can use it as an exit node.

**Known Remaining Warning**

IPv6 forwarding is not enabled — `net.ipv6.conf.all.forwarding` is not set. The exit node functions for IPv4 traffic only. IPv6 client traffic will not route through the server.

---

## 10. SMB File Sharing

- SMB is enabled for:
  - Home directory
  - `/mnt/storage`
- Used to add and access media files remotely over Tailscale
- Intended for trusted users only

Usage expectations:
- Mostly append-only media files
- Not used as a transactional datastore

---

## 11. Backups

**Frequency**
- Weekly

**Type**
- Cold backups (offline when not in use)

**Scope**
- Media library
- Jellyfin configuration

**Recovery**
- Drive replacement and restore tested
- Recovery achievable in under 1 hour

---

## 12. Jellyfin Configuration Backup & Restore

This section documents how Jellyfin configuration and state are backed up and restored.
Media files are treated separately and are not covered here.

**Scope**

Included:
- Server configuration
- User accounts
- Watch history
- Library definitions
- Plugins and plugin configuration
- Jellyfin SQLite database (`jellyfin.db`)

Excluded by design:
- Media files
- Artwork, thumbnails, and metadata images
- Cache and transcode data

Rationale:
Configuration and database state are authoritative and must be preserved.
Metadata and cache are derived data and can be regenerated.

### Backup Procedure (Automated Steps, Manual Trigger)

The steps below are automated by `server/bin/jellyfin-backup` (dotfiles). It
runs on this server — stopping Jellyfin, archiving `config` (excluding
`cache`/`metadata`), restarting Jellyfin immediately to minimize downtime,
then pushing the finished archive out to the Mac (`~/dev/server/`) over
Tailscale SSH, and cleaning up the temporary archive on this server.

The trigger is intentionally still manual (`./bin/jellyfin-backup`, run by
hand): the destination is a laptop, not an always-on node, so a systemd
timer isn't viable until both ends are confirmed awake. The manual steps
below remain the reference for what the script does, and for restoring by
hand if ever needed.

### Backup Procedure (Manual)

**Preconditions**
- Jellyfin service must be stopped briefly to ensure database consistency.
- Backup file will be created on the server, then copied off-host.

**Steps**

1. Stop Jellyfin  
   sudo systemctl stop jellyfin.service

2. Create the backup archive  
   sudo tar -C /var/lib/jellyfin --exclude=cache --exclude=metadata -czf /tmp/jellyfin-config-backup.tar.gz config

3. Restart Jellyfin  
   sudo systemctl start jellyfin.service

4. Copy the backup to a safe location (example: Mac over Tailscale)  
   scp eli@100.106.45.25:/tmp/jellyfin-config-backup.tar.gz ~/jellyfin-config-backup.tar.gz

5. Rename the backup with the current date  
   mv ~/jellyfin-config-backup.tar.gz ~/jellyfin-config-YYYY-MM-DD.tar.gz

6. (Optional) Remove temporary backup file from the server  
   sudo rm /tmp/jellyfin-config-backup.tar.gz

The backup file should be small (tens to hundreds of MB) and complete in seconds.

### Restore Procedure (Full Restore)

This procedure is used after:
- OS reinstall
- System migration
- Root disk failure
- Severe configuration corruption

**Preconditions**
- Jellyfin container and service are installed
- Paths match original deployment:
  - /var/lib/jellyfin/config
  - /var/lib/jellyfin/cache
  - /mnt/storage mounted correctly

**Steps**

1. Stop Jellyfin  
   sudo systemctl stop jellyfin.service

2. Remove existing configuration directory  
   sudo rm -rf /var/lib/jellyfin/config

3. Copy backup archive onto the server  
   scp ~/jellyfin-config-YYYY-MM-DD.tar.gz eli@100.106.45.25:/tmp/

4. Extract the backup  
   sudo tar -C /var/lib/jellyfin -xzf /tmp/jellyfin-config-YYYY-MM-DD.tar.gz

5. Ensure correct ownership  
   sudo chown -R eli:eli /var/lib/jellyfin/config

6. Start Jellyfin  
   sudo systemctl start jellyfin.service

**Post-Restore Expectations**
- Jellyfin starts normally
- All users and watch history are restored
- Libraries reconnect to existing media
- Artwork and thumbnails regenerate automatically over time

**Notes**
- Metadata artwork under `config/metadata` is intentionally excluded from backups.
- Cache directories are disposable and never backed up.
- Restore should always be performed with Jellyfin stopped.
- Backups are safe to store off-host (e.g., Mac with Time Machine, Google Drive).

---

## 13. Update Policy

**Automatic**
- Security updates only
- Applied weekly

**Manual**
- OS package updates
- Podman updates
- Container image updates (Jellyfin, Transmission, NordVPN)

See section 5 for the Jellyfin image update procedure, section 6 for the Transmission image update procedure and NordVPN container rebuild procedure.

---

## 14. Routine Checks

### Daily Health Check (doctor)

`doctor` checks storage, services, VPN tunnel, drive temperature, recent reboots, and Tailscale. Exits 0=ok, 1=warn, 2=crit.

```sh
doctor
```

A systemd user timer runs `doctor-check` daily at 6am, caching the result to `~/.local/state/doctor/status`. The fish greeting reads this cache and displays any warnings or criticals on login.

`doctor` requires passwordless sudo for two commands. These are configured in `/etc/sudoers.d/doctor`:

```
eli ALL=(ALL) NOPASSWD: /usr/bin/podman exec nordvpn nordvpn status
eli ALL=(ALL) NOPASSWD: /usr/sbin/blkid -U d477f156-a70d-4aba-ab3d-5fa6d194e982
eli ALL=(ALL) NOPASSWD: /usr/sbin/smartctl -d sat -l scttemp /dev/sd*
```

To edit:
```sh
sudo visudo -f /etc/sudoers.d/doctor
```

To enable the timer (once, after initial setup):
```sh
systemctl --user enable --now doctor-check.timer
```

### Kernel Cleanup

DNF keeps old kernels (and their `-core`/`-devel`/`-modules`/`-modules-extra` packages) installed alongside the current one. Periodically remove everything except the running kernel:

```sh
sudo dnf remove --oldinstallonly
```

Typically frees several hundred MB. Safe to run any time — `dnf` always keeps the currently-running kernel regardless of install order.

### Check Storage Mount
```sh
mountpoint /mnt/storage
```
### Check Container State
```sh
podman ps -a
```
### Check Recent System Events
```sh
last -x | head -n 30
```

## 15. Common Failure Scenarios

### Jellyfin Not Running
1. Check service status

```sh
   sudo systemctl status jellyfin.service
```
2. Verify `/mnt/storage` is mounted

```sh  
   mountpoint /mnt/storage
```
3. Restart Jellyfin

```sh  
   sudo systemctl restart jellyfin.service
```
---

### Media Missing in Jellyfin
Confirm `/mnt/storage` is mounted  

```sh   
   mountpoint /mnt/storage
```

Check USB dock power and cabling

Restart Jellyfin  

```sh   
   sudo systemctl restart jellyfin.service
```
Reboot the system if necessary  

```sh
   sudo reboot now
```
---

### Disk Failure
1. Power down the system  
   sudo poweroff

2. Replace the disk in the USB dock

3. Restore data from weekly cold backup

4. Boot system and verify Jellyfin functionality

---

### NordVPN Not Connecting

1. Check service status
```bash
sudo systemctl status nordvpn.service
```
2. Check VPN status directly
```bash
sudo podman exec nordvpn nordvpn status
```
3. If token has expired, regenerate and update the Podman secret, then restart
```bash
sudo podman secret rm nordvpn_token
echo -n "new-token" | sudo podman secret create nordvpn_token -
sudo systemctl restart nordvpn.service
```

---

### Transmission Not Running

1. Check service status
```bash
sudo systemctl status transmission.service
```
2. Verify nordvpn is connected -- transmission will not start without it
```bash
sudo podman exec nordvpn nordvpn status
```
3. Restart transmission
```bash
sudo systemctl restart transmission.service
```

---

### Leftover Containers Blocking Start

This is handled automatically by the nordvpn service pre-start steps. If manual cleanup is needed:
```bash
sudo podman rm -f transmission
sudo podman rm -f nordvpn
sudo systemctl restart nordvpn.service
```

---

### mintmedia Not Running

The service is `Type=simple` with `Restart=on-failure`, so systemd tracks the actual daemon process — `active`/`failed` in `systemctl --user status` reflects reality.

1. Check status and recent logs
```bash
systemctl --user status mintmedia.service
journalctl --user-unit=mintmedia.service -n 50
```

2. Restart if needed
```bash
systemctl --user restart mintmedia.service
```

---

### Verifying Torrent Traffic Uses VPN

With an active torrent, peer connections should show `10.5.0.2` (VPN tunnel) as the local address:
```bash
sudo podman exec transmission netstat -tnp | grep 51413
```

---

## 16. Known Design Decisions

- Single-node deployment by design
- USB-attached storage accepted as a trade-off
- Always-on deployment; power cuts are unplanned upstream events only
- Jellyfin lifecycle tied to storage mount availability
- SELinux remains enabled
- Manual updates preferred for non-security changes
- Upstream power cuts may interrupt in-progress downloads. Transmission resumes incomplete downloads on restart.
- Transmission is not configured with RPC authentication. Access is restricted to Tailscale, which provides authentication at the network level.
- NordVPN token expires annually. Failure to renew will cause the nordvpn service to fail on restart.
- The nordvpn container image (`localhost/nordvpn-custom:latest`) is built locally from source files in `~/nordvpn-image/`. Rebuilding after a NordVPN update requires pulling the new package and rebuilding the image.

### Package Removal — 2026-07-25 Security Audit

Two unused package sets were identified during a firewall/attack-surface audit and removed:

**NFS client tooling** (`rpcbind`, `nfs-utils`, `libnfsidmap`, `nfs4-acl-tools`) — file sharing on this server is SMB-only (see Section 10). NFS was never configured; `rpcbind` had no exports to serve and was just an open port (111/tcp+udp) on every interface.

**Domain-join tooling** (`sssd` and its sub-packages, `realmd`, `adcli`) — this server uses local-only accounts. Before removal, `authselect current` confirmed the active profile (`local`) does not reference `sss` anywhere in `passwd`/`group`/`shadow` in `nsswitch.conf`, so the removal has no effect on login/auth.

```bash
sudo dnf remove nfs-utils nfs4-acl-tools libnfsidmap rpcbind sssd sssd-ad sssd-client sssd-common sssd-common-pac sssd-ipa sssd-kcm sssd-krb5 sssd-krb5-common sssd-ldap sssd-nfs-idmap sssd-proxy libsss_idmap libsss_certmap libipa_hbac libsss_nss_idmap libsss_sudo realmd adcli adcli-selinux
```

**Side effect**: `bind-utils` (provides `dig`, `nslookup`, `host`) was installed only as an `sssd` dependency and was swept out along with it. Reinstall if DNS diagnostic tools are needed:
```bash
sudo dnf install bind-utils
```

---

## 17. Shell Tooling

### lf (terminal file manager)

Not available in DNF repos. Installed via Go:

```sh
go install github.com/gokcehan/lf@latest
```

Config is at `~/.config/lf/` (sourced from `server/lf/` in dotfiles):
- `lfrc` — keybindings and settings; no zoxide, no image previews
- `pv.sh` — text file previewer (bat with cat fallback)
- `icons` — Nerd Font icon mappings

The `lf` fish function (`~/.config/fish/functions/lf.fish`) wraps lf with quit-and-cd integration.

---

## 18. Final Notes

This system is intentionally simple and conservative.

If something unexpected happens:
- Prioritize data integrity over uptime
- Favor restarts over live debugging
- Restore from backup rather than attempting complex repair
