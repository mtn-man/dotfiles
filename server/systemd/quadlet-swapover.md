# Quadlet Swapover — jellyfin, nordvpn, transmission

Procedure for cutting `jellyfin.service`, `nordvpn.service`, and `transmission.service`
over from hand-written systemd units to Podman Quadlet `.container` files. Drafted
2026-07-27, to be run on the homelab server.

Source files (already drafted, not yet committed as of this writing):
- `~/.dotfiles/server/systemd/jellyfin.container`
- `~/.dotfiles/server/systemd/nordvpn.container`
- `~/.dotfiles/server/systemd/transmission.container`

The corresponding `.service` files are left in place in the dotfiles repo (not deleted)
as a fallback reference — only the *deployed* copies in `/etc/systemd/system/` get
removed, one pair at a time, below.

Podman version on the server: 6.0.1 — confirmed well past the point Quadlet is
considered stable.

---

## 0. Prerequisites

Get the three `.container` files onto the server. Either:

**a) Commit + push on the Mac, pull on the server** (recommended — this is the point
of tracking them):
```sh
# On the Mac, in ~/.dotfiles
git add server/systemd/jellyfin.container server/systemd/nordvpn.container server/systemd/transmission.container
git commit -m "server: add Quadlet .container files for jellyfin, nordvpn, transmission"
git push
```
```sh
# On the server, in your dotfiles checkout
git pull
```

**b) Or scp directly** if you'd rather test before committing:
```sh
scp ~/.dotfiles/server/systemd/{jellyfin,nordvpn,transmission}.container eli@100.106.45.25:~/
```

Either way, confirm all three files are present on the server before starting Phase 1.

---

## Phase 1 — jellyfin (independent, do this first)

```sh
sudo systemctl stop jellyfin.service
sudo rm /etc/systemd/system/jellyfin.service
sudo cp ~/.dotfiles/server/systemd/jellyfin.container /etc/containers/systemd/jellyfin.container
sudo systemctl daemon-reload
sudo podman rm -f jellyfin
sudo systemctl start jellyfin.service
```

**Verify:**
```sh
systemctl status jellyfin.service
podman ps        # NAMES column should read "jellyfin" (not "jellyfin-systemd")
```
- Wait ~2 min, confirm health status flips to `healthy` (`--health-start-period=120s`).
- Load the UI over Tailscale: `http://100.106.45.25:8096`.
- Play something that needs hardware transcoding — confirms `/dev/dri` passthrough
  still works.
- `doctor` should report `jellyfin: ok`.

**If something's wrong, roll back:**
```sh
sudo systemctl stop jellyfin.service
sudo rm /etc/containers/systemd/jellyfin.container
sudo cp ~/.dotfiles/server/systemd/jellyfin.service /etc/systemd/system/jellyfin.service
sudo systemctl daemon-reload
sudo podman rm -f jellyfin
sudo systemctl start jellyfin.service
```

Don't proceed to Phase 2 until Phase 1 looks solid.

---

## Phase 2 — nordvpn + transmission (coupled — swap together, not incrementally)

`transmission.container` uses `Network=nordvpn.container`, which only resolves against
a nordvpn container that is itself Quadlet-managed. Leaving the old `nordvpn.service`
in place (it shadows/wins over a same-named generated unit) while dropping in
`transmission.container` would leave transmission with nothing valid to attach to — so
both go over in the same window. Transmission stops first, same as the existing
runbook rule, since it depends on nordvpn's network namespace.

```sh
sudo systemctl stop transmission.service
sudo systemctl stop nordvpn.service
sudo rm /etc/systemd/system/transmission.service /etc/systemd/system/nordvpn.service
sudo cp ~/.dotfiles/server/systemd/nordvpn.container /etc/containers/systemd/nordvpn.container
sudo cp ~/.dotfiles/server/systemd/transmission.container /etc/containers/systemd/transmission.container
sudo systemctl daemon-reload
sudo systemctl start nordvpn.service
```

**Confirm VPN is connected before starting transmission** (don't skip — avoids burning
transmission's own 120s connect-wait loop on a dead VPN):
```sh
sudo podman exec nordvpn nordvpn status
# must show: Status: Connected
```

```sh
sudo systemctl start transmission.service
```

**Verify:**
```sh
systemctl status nordvpn.service
systemctl status transmission.service
podman ps        # both "nordvpn" and "transmission" present
sudo podman exec transmission netstat -tnp | grep 51413    # should show 10.5.0.2 (VPN tunnel)
```
- Transmission Web UI reachable at `http://100.106.45.25:9091/transmission/`.
- `doctor` should report `vpn tunnel: connected` and `transmission: ok`.
- mintmedia (separate user service, untouched) should still see Transmission over RPC
  at `100.106.45.25:9091` — no action needed, just don't be surprised if you check it.

**If something's wrong, roll back** (reverse order — nordvpn's the dependency, so
bring transmission down first, then swap both back, then bring nordvpn back up first):
```sh
sudo systemctl stop transmission.service
sudo systemctl stop nordvpn.service
sudo rm /etc/containers/systemd/nordvpn.container /etc/containers/systemd/transmission.container
sudo cp ~/.dotfiles/server/systemd/nordvpn.service /etc/systemd/system/nordvpn.service
sudo cp ~/.dotfiles/server/systemd/transmission.service /etc/systemd/system/transmission.service
sudo systemctl daemon-reload
sudo systemctl start nordvpn.service
# confirm "Status: Connected" before continuing
sudo systemctl start transmission.service
```

---

## Phase 3 — reboot test (do this last, once both phases look stable)

None of this is really validated until it survives a cold boot — the storage
spin-up wait loops and the `PartOf=`/`Requires=` ordering only actually get
exercised on boot, not on a manual `systemctl start`.

```sh
sudo reboot
```

After it comes back up, unattended:
```sh
doctor
podman ps
systemctl status jellyfin.service nordvpn.service transmission.service
```
All three should be up with no manual intervention. `doctor` exit code 0 = clean.

---

## Not part of tomorrow's run — later cleanup

Once this has run stable for a while:
- Delete the old `.service` files from the dotfiles repo (`server/systemd/*.service`).
- Update `runbook.md` §5/§6 references from `/etc/systemd/system/*.service` to
  `/etc/containers/systemd/*.container`.

Don't do this yet — the `.service` files are the rollback path until the Quadlet
versions have proven themselves.
