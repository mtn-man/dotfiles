# Media Server Runbook (CentOS Stream 10)

> This is a sanitized template. The real, filled-in runbook is `runbook.md`
> (gitignored, not tracked) — copy this file to `runbook.md` and replace the
> `<placeholder>` values (Tailscale IP, MagicDNS hostname, disk UUID, local
> username) with real ones.

> Dated investigation notes, forensic detail, and old audit-trail commands
> live in `server-history.md` instead of here — this document stays
> focused on current architecture and operations.

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
- Tailscale only by default; no LAN exposure of Jellyfin/SSH/Samba (Section 8)
- `tailscale serve` reverse-proxies HTTPS for Jellyfin and Cockpit on top of Tailscale's own access control (Section 5)
- Two explicit exceptions to tailnet-only access: Jellyfin is reachable from the public internet via Tailscale Funnel, enabled since 2026-07-26 behind a hardening checklist (Section 5); Cockpit is reachable on the LAN as an intentional troubleshooting fallback if Tailscale itself is down (Section 8)

---

## 3. Power and Boot Model

- System runs always-on
- Power cuts are unplanned (upstream outages only)
- System boots automatically after power is restored

Design assumption:
- USB storage may take significant time to spin up and enumerate after an unplanned power cut

Mitigation:
- Jellyfin, NordVPN, and Transmission startup are all explicitly tied to storage availability via `Requires=mnt-storage.mount`
- None of these services start until storage is mounted; all stop if storage disappears
- If `/mnt/storage` isn't ready by the time systemd first evaluates these services at boot, their start jobs fail with a "dependency" result. Systemd does not automatically retry a dependency-failed job on its own once the mount later succeeds — a service that only `Requires=` the mount can be left permanently `inactive` even after storage comes online.
- `/etc/systemd/system/mnt-storage.mount.d/override.conf` closes that gap:
  ```ini
  [Unit]
  Wants=jellyfin.service nordvpn.service transmission.service
  ```
  This is a forward dependency declared on the mount unit itself, not on the services. Whenever `mnt-storage.mount` (re-)starts — including a delayed, udev-triggered mount after a slow USB enumeration — that job's own transaction pulls in all three services fresh, regardless of whether their own earlier start attempt already failed. This is what lets them self-heal after a slow boot instead of needing a manual restart (see `server-history.md` for the boot race that originally exposed this gap). A typical reboot mounts storage within seconds; a massively delayed mount is expected to be a rare edge case, but the fix costs nothing to leave in place.

---

## 4. Storage Layout

**Enclosure**: TerraMaster D2-320 (2-bay USB DAS). Only bay 1 is populated; bay 2 is free for future expansion. `/mnt/storage` is mounted by the XFS filesystem UUID, not by enclosure or `/dev/sdX` device node, so the drive can migrate enclosures with no fstab changes required.

| Path | Purpose | Notes |
|-----|--------|-------|
| `/` | OS | XFS |
| `/home` | User data | XFS |
| `/mnt/storage` | Media library | XFS, USB-attached (TerraMaster D2-320 DAS) |
| `/mnt/storage/Movies` | Processed movies | mintmedia destination |
| `/mnt/storage/Shows` | Processed TV shows | mintmedia destination |
| `/mnt/storage/Downloads` | Transmission download root | |
| `/mnt/storage/Downloads/complete` | Completed downloads; mintmedia watch folder | Default linuxserver/transmission layout |
| `/mnt/storage/Downloads/incomplete` | In-progress downloads | |
| `/var/lib/jellyfin/config` | Jellyfin configuration | Persistent |
| `/var/lib/jellyfin/cache` | Jellyfin cache | Persistent |
| `/var/lib/transmission/config` | Transmission configuration | Persistent |

**Storage Characteristics**
- Full SMART data is available via the D2-320's SAT-compliant USB bridge, including the SCT temperature history table and the dedicated SMART status query (see `server-history.md` for the prior enclosure's SMART limitations)
- The drive intentionally does not spin down when idle — APM is disabled on the drive itself (WD Gold WD102KRYZ, a 24/7 enterprise-duty model), which is correct for a drive rated for continuous spinning rather than frequent load/unload cycling; see `server-history.md` for the investigation
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
- Requires `/mnt/storage` to be mounted; self-heals after a delayed mount via the `Wants=` drop-in described in Section 3
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

**Result** — `https://<hostname>.<tailnet-name>.ts.net` (tailnet-only, valid cert, no browser warning) alongside the existing `http://<tailscale-ip>:8096`.

### Public Internet Access via Tailscale Funnel

Funnel extends the `serve` rule above to the public internet (not just the tailnet), at the same hostname, so friends/family can connect without installing Tailscale.

**Status: Enabled since 2026-07-26.** Jellyfin is the one explicit exception to the tailnet-only access model (Section 2) — this is the only service reachable from the public internet. The hardening checklist in `~/dev/server/jellyfin-funnel-checklist.md` (account lockout, permissions, resource caps, backup automation, kill switch) was completed first. Sign-in attempts and access records are monitored on an ongoing basis; only authorized traffic has been observed so far.

**Hardening applied (prerequisite to enabling Funnel)**
- **Permissions**: user accounts are scoped to read-only access on only the libraries they need — no write/delete permissions
- **Resource caps**: each user account is limited to 2 concurrent streams
- **Account hygiene**: inactive user accounts disabled; stricter password requirements enabled for all accounts
- **Admin account**: password rotated to a long, high-entropy random string; admin login hidden from the main landing page
- **Account lockout**: 5 failed sign-in attempts locks a standard account, 3 for the admin account. fail2ban was evaluated and ruled out — it can't see real client IPs behind Funnel, since Tailscale terminates and proxies the connection — so lockout is enforced by Jellyfin's own account-lockout setting instead
- **2FA plugin**: considered a third-party Jellyfin 2FA plugin for the admin account, decided against — added third-party attack surface for a benefit that's currently theoretical (no illicit sign-on attempts observed yet). Revisit if that changes

**Enable** (already applied; reference for re-enabling after a kill-switch disable)
```bash
sudo tailscale funnel --bg --https=443 http://localhost:8096
```

**Check status**
```bash
tailscale serve status
```

**Kill switch / disable** — pulls Jellyfin off the public internet immediately without touching tailnet access, for suspected compromise, abuse, or anything that looks wrong. This is the exact command `tailscale funnel` itself echoes back after enabling:
```bash
sudo tailscale funnel --https=443 off
```
This clears only the funnel (public) config for port 443; it does not touch the `serve` rule above, so Jellyfin stays reachable over the tailnet exactly as it does today. (`sudo tailscale funnel reset` is a broader alternative that clears *all* funnel rules on the node, not just this one — prefer the scoped command above unless you specifically want that.) If this command ever looks stale, see `server-history.md` — the CLI has changed this syntax before.

### Jellyfin Image Update Procedure

The Jellyfin service uses `--pull=never`, so a new image must be pulled explicitly before restarting. The image runs under the `<user>` user account, so no `sudo` is needed for the pull.

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

4. Verify Jellyfin UI loads — `http://<tailscale-ip>:8096` over Tailscale

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
- Transmission RPC is published exclusively to the Tailscale interface (`<tailscale-ip>:9091`)

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

### Known Non-Leak: nordvpnd Control-Plane Traffic on the Bridge

Bridge-sourced connections (`10.88.0.3`) to arbitrary external IPs are expected — `nordvpnd`'s kill switch exempts its own control-plane traffic (fwmark `0xe1f1`) from the forced-VPN table. Only `10.5.0.2`-sourced (tunnel) traffic needs to be verified as VPN-routed; see `server-history.md` for how this was confirmed.

---

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
- Web UI: `http://<tailscale-ip>:9091/transmission/` (Tailscale only)
- RPC endpoint: `http://<tailscale-ip>:9091/transmission/rpc`

---

## 7. mintmedia Service

**Purpose**
- Watches `/mnt/storage/Downloads/complete` for completed downloads
- Renames and moves media to `/mnt/storage/Movies` or `/mnt/storage/Shows`
- Does not talk to Transmission directly — Transmission's own "move completed downloads to" setting drops finished files into the watch folder; mintmedia only reacts to what appears there

**Service Type**
- systemd user service, running the mintmedia daemon directly (`Type=simple`)

**Service File**
`~/.config/systemd/user/mintmedia.service`

**Key Design Points**
- Runs as a user service under `<user>`; linger is enabled so it starts at boot without login
- `Restart=on-failure` — systemd restarts the daemon automatically if it exits unexpectedly
- Built and updated manually from source at `~/dev/golang/mintmedia`
- Transmission RPC integration (`[torrent]` / clipboard automation) is disabled in this instance's config — the server is headless, so there's no desktop session or clipboard to ingest magnet links from. That role is handled from the Mac (`tm.fish`, or the Mac's own mintmedia instance pointed at `<tailscale-ip>:9091`), which sends links/torrents to the server's Transmission over Tailscale
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
- Reading the journal requires membership in the `systemd-journal` group (one-time): `sudo usermod -aG systemd-journal <user>`, then re-login.
- Structured processing history: `~/.local/state/mintmedia/history.jsonl`

---

## 8. Networking and Access

**Access Model**
- Tailscale provides encrypted access
- One exception: Jellyfin is exposed to the public internet via Tailscale Funnel on 443, hardened and monitored — see Section 5

**Services Accessible Over Tailscale**
- Jellyfin (HTTP on 8096, HTTPS on 443 via `tailscale serve`; also public via Funnel — see Section 5)
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

The `public` zone previously exposed SSH/Samba/Jellyfin in contradiction of the Tailscale-only access model; see `server-history.md` for the cleanup commands and what was removed.

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

**Result** — `https://<hostname>.<tailnet-name>.ts.net:8443` (tailnet-only, valid cert, no browser warning), added *alongside* the existing direct access on `http://<tailscale-ip>:9090` and the LAN-only `public` zone exposure (Section 8, Firewalld Zone Configuration). The direct paths are left in place intentionally — they're the fallback if Tailscale itself is ever down.

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

## 9. SMB File Sharing

- SMB is enabled for:
  - Home directory
  - `/mnt/storage`
- Used to add and access media files remotely over Tailscale
- Intended for trusted users only

Usage expectations:
- Mostly append-only media files
- Not used as a transactional datastore

---

## 10. Backups

Two independent mechanisms cover this system — different scope, cadence, and destination each. Jellyfin configuration is detailed further in Section 11.

**Media Library**
- Frequency: Weekly
- Type: Cold backup (offline when not in use)
- Trigger: `server/bin/backup` (dotfiles), run by hand
- Recovery: Drive replacement and restore tested; achievable in under 1 hour

**Jellyfin Configuration**
- Frequency: Manual / ad hoc — trigger is intentionally not automated (Section 11)
- Type: Archived and pushed off-host to the Mac over Tailscale SSH
- Trigger: `server/bin/jellyfin-backup` (dotfiles), run by hand

---

## 11. Jellyfin Configuration Backup & Restore

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
   scp <user>@<tailscale-ip>:/tmp/jellyfin-config-backup.tar.gz ~/jellyfin-config-backup.tar.gz

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
   scp ~/jellyfin-config-YYYY-MM-DD.tar.gz <user>@<tailscale-ip>:/tmp/

4. Extract the backup  
   sudo tar -C /var/lib/jellyfin -xzf /tmp/jellyfin-config-YYYY-MM-DD.tar.gz

5. Ensure correct ownership  
   sudo chown -R <user>:<user> /var/lib/jellyfin/config

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

## 12. Update Policy

**Automatic**
- Security updates only
- Applied weekly

**Manual**
- OS package updates
- Podman updates
- Container image updates (Jellyfin, Transmission, NordVPN)

See section 5 for the Jellyfin image update procedure, section 6 for the Transmission image update procedure and NordVPN container rebuild procedure.

---

## 13. Routine Checks

### Daily Health Check (doctor)

`doctor` checks storage, services, VPN tunnel, drive temperature, recent reboots, and Tailscale. Exits 0=ok, 1=warn, 2=crit.

```sh
doctor
```

A systemd user timer runs `doctor-check` daily at 6am, caching the result to `~/.local/state/doctor/status`. The fish greeting reads this cache and displays any warnings or criticals on login.

`doctor` requires passwordless sudo for two commands. These are configured in `/etc/sudoers.d/doctor`:

```
<user> ALL=(ALL) NOPASSWD: /usr/bin/podman exec nordvpn nordvpn status
<user> ALL=(ALL) NOPASSWD: /usr/sbin/blkid -U <disk-uuid>
<user> ALL=(ALL) NOPASSWD: /usr/sbin/smartctl -d sat -l scttemp /dev/sd*
<user> ALL=(ALL) NOPASSWD: /usr/sbin/smartctl -H -A -d sat /dev/sd*
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

## 14. Common Failure Scenarios

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

Check DAS power and cabling

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

2. Replace the disk in the DAS

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

## 15. Known Design Decisions

- Single-node deployment by design
- USB-attached storage accepted as a trade-off
- Drive is intentionally left spinning 24/7 (no APM/spin-down); see Storage Characteristics in Section 4
- Always-on deployment; power cuts are unplanned upstream events only
- Jellyfin lifecycle tied to storage mount availability
- SELinux remains enabled
- Manual updates preferred for non-security changes
- Upstream power cuts may interrupt in-progress downloads. Transmission resumes incomplete downloads on restart.
- Transmission is not configured with RPC authentication. Access is restricted to Tailscale, which provides authentication at the network level.
- NordVPN token expires annually. Failure to renew will cause the nordvpn service to fail on restart.
- The nordvpn container image (`localhost/nordvpn-custom:latest`) is built locally from source files in `~/nordvpn-image/`. Rebuilding after a NordVPN update requires pulling the new package and rebuilding the image.
- Jellyfin is intentionally exposed to the public internet via Tailscale Funnel (enabled 2026-07-26), the sole exception to the tailnet-only access model. fail2ban was evaluated and ruled out — it can't see real client IPs behind Funnel's proxy — so brute-force protection relies on the checklist's other hardening steps instead. Access logs are monitored on an ongoing basis; see Section 5.
- NFS client tooling and domain-join tooling (`sssd`, `realmd`, etc.) are not installed — this server is SMB-only with local accounts. See `server-history.md` for the 2026-07-25 audit that removed them.

---

## 16. Shell Tooling

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

## 17. Final Notes

This system is intentionally simple and conservative.

If something unexpected happens:
- Prioritize data integrity over uptime
- Favor restarts over live debugging
- Restore from backup rather than attempting complex repair
