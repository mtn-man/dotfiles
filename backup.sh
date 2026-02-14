#!/usr/bin/env bash
set -euo pipefail

# ---- Config ----
SRC="/mnt/storage/"
MNT="/mnt/media"
DST="${MNT}/media/"

# Cold backup disk identity
COLD_UUID="304ef819-5382-40c5-964a-20726cb98c7b"

# Sentinel files
SRC_SENTINEL="${SRC}.BACKUP_SOURCE_OK"
DST_SENTINEL="${MNT}/.BACKUP_DEST_OK"   # must live outside mirrored tree

# rsync options
PARTIAL_DIR="${DST}.rsync-partial"

# ---- State ----
keepalive_pid=""
rsync_ok=0

cleanup() {
    # Stop sudo keep-alive
    if [[ -n "${keepalive_pid}" ]]; then
        kill "${keepalive_pid}" 2>/dev/null || true
    fi

    # Always unmount on SUCCESSFUL path
    if [[ "${rsync_ok}" -eq 1 ]]; then
        echo "Flushing buffers..."
        sync || true

        echo "Attempting to unmount ${MNT}..."
        if sudo umount "${MNT}"; then
            echo "Unmount successful — safe to disconnect after spindown."
        else
            echo "WARNING: Unmount failed; filesystem may be busy."
            echo "Open files:"
            sudo lsof +f -- "${MNT}" 2>/dev/null || true
            sudo fuser -v "${MNT}" 2>&1 || true
            exit 1
        fi
    fi
}
trap cleanup EXIT

echo "Starting backup..."

sudo -v
echo "Sudo authenticated"

# Start sudo keep-alive
( while true; do sudo -n true || exit 0; sleep 60; done ) &
keepalive_pid="$!"
echo "Keep-alive PID: ${keepalive_pid}"

# ---- Safety: source sentinel must exist ----
if [[ ! -e "${SRC_SENTINEL}" ]]; then
    echo "ABORT: Missing source sentinel ${SRC_SENTINEL}" >&2
    exit 1
fi

# ---- Ensure destination mounted ----
if ! mountpoint -q "${MNT}"; then
    echo "${MNT} not mounted, attempting to mount cold disk..."
    sudo mount "UUID=${COLD_UUID}" "${MNT}" || {
        echo "ERROR: Failed to mount ${MNT}" >&2
        exit 1
    }
else
    echo "${MNT} already mounted"
fi

# ---- GUARD: verify correct disk is mounted ----
if ! mountpoint -q "${MNT}"; then
    echo "ABORT: ${MNT} is not mounted" >&2
    exit 1
fi

mounted_uuid="$(findmnt -n -o UUID --target "${MNT}" 2>/dev/null || true)"

if [[ -z "${mounted_uuid}" ]]; then
    echo "ABORT: Could not determine UUID for mount at ${MNT}" >&2
    echo "Debug SOURCE: $(findmnt -n -o SOURCE --target "${MNT}" 2>/dev/null || true)" >&2
    exit 1
fi

if [[ "${mounted_uuid}" != "${COLD_UUID}" ]]; then
    echo "ABORT: ${MNT} is not the expected backup disk." >&2
    echo "Found UUID=${mounted_uuid}, expected ${COLD_UUID}" >&2
    exit 1
fi

# ---- Safety: destination sentinel must exist ----
if [[ ! -e "${DST_SENTINEL}" ]]; then
    echo "ABORT: Missing destination sentinel ${DST_SENTINEL}" >&2
    exit 1
fi

# Informational space check
dest_free_kb="$(df -k --output=avail "${MNT}" | tail -n 1 | xargs)"
echo "Destination free space: ${dest_free_kb} KB"

# ---- Run rsync ----
echo "Running rsync..."
sudo rsync -avh \
    --delete \
    --delete-delay \
    --progress \
    --exclude='.BACKUP_SOURCE_OK' \
    --partial-dir="${PARTIAL_DIR}" \
    "${SRC}" "${DST}"

echo "rsync completed successfully"
rsync_ok=1
echo "backup completed cleanly"
