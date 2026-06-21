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
| `/var/lib/jellyfin/config` | Jellyfin configuration | Persistent |
| `/var/lib/jellyfin/cache` | Jellyfin cache | Persistent |

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
- Container health checks enabled

**Check the Service**
```sh
sudo systemctl status jellyfin.service
```

**Restart the Service**
```sh
sudo systemctl restart jellyfin.service
```

---

## 5a. VPN + Transmission Service

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
| `/mnt/storage/Downloads/MintDrop` | Completed downloads (watched by mintmedia) |
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

## 6. Networking and Access

**Access Model**
- Tailscale provides encrypted access
- No ports exposed to the public internet

**Services Accessible Over Tailscale**
- Jellyfin (HTTP)
- SMB
- SSH

**Notes**
- Tailscale CGNAT ranges must NOT be listed as "Known Proxies" in Jellyfin
- Jellyfin LAN subnet includes the Tailscale address range

---

## 7. SMB File Sharing

- SMB is enabled for:
  - Home directory
  - `/mnt/storage`
- Used to add and access media files remotely over Tailscale
- Intended for trusted users only

Usage expectations:
- Mostly append-only media files
- Not used as a transactional datastore

---

## 8. Backups

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

## 8a. Jellyfin Configuration Backup & Restore

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

## 9. Update Policy

**Automatic**
- Security updates only
- Applied weekly

**Manual**
- OS package updates
- Podman updates
- Jellyfin container image updates

**Manual Update Procedure**
1. Pull or update image manually
2. Restart Jellyfin service
3. Verify Jellyfin UI loads
4. Verify media playback
5. Verify thumbnails load

---

## 10. Routine Checks

### Check Storage Mount
```sh
mountpoint /mnt/storage
```
### Check Container State
```sh
podman ps -a
```
### Check Drive Temperature
```sh
drive-temp
```
### Check Recent System Events
```sh
last -x | head -n 30
```

## 11. Common Failure Scenarios

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

### Verifying Torrent Traffic Uses VPN

With an active torrent, peer connections should show `10.5.0.2` (VPN tunnel) as the local address:
```bash
sudo podman exec transmission netstat -tnp | grep 51413
```

---

## 12. Known Design Decisions

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

---

## 13. Final Notes

This system is intentionally simple and conservative.

If something unexpected happens:
- Prioritize data integrity over uptime
- Favor restarts over live debugging
- Restore from backup rather than attempting complex repair
