#!/bin/bash

# === AUTOMATED SYSTEM BACKUP FOR DUMMIES ===
# Arch Linux + GNOME + Wayland
# Timeshift local snapshot + Encrypted Restic cloud backup

set -euo pipefail

CONFIG_FILE="./autosave.conf"
LOG_FILE="$HOME/.local/share/autosave/autosave.log"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SNAPSHOT_COMMENT="Snapshot $TIMESTAMP"

log() {
    echo "[autosave-file] $1" | tee -a "$LOG_FILE"
}

check_dependencies() {
    local deps=(timeshift restic rclone findmnt tee date)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log "Missing dependency: $cmd"
            exit 1
        fi
    done
}

install_timeshift() {
    if ! command -v timeshift &>/dev/null; then
        log "Installing Timeshift..."
        sudo pacman -Sy --noconfirm timeshift
    fi
}

detect_filesystem() {
    ROOT_FS=$(findmnt -n -o FSTYPE /)
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        BACKUP_TYPE="BTRFS"
    elif [[ "$ROOT_FS" == "ext4" || "$ROOT_FS" == "xfs" ]]; then
        BACKUP_TYPE="RSYNC"
    else
        log "Unsupported filesystem: $ROOT_FS"
        exit 1
    fi
    log "Using $BACKUP_TYPE mode"
}

create_timeshift_snapshot() {
    log "Creating Timeshift snapshot..."
    sudo timeshift --create --comments "$SNAPSHOT_COMMENT" --tags D
    log "Snapshot created."
}

run_cloud_backup() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "Missing cloud config at $CONFIG_FILE"
        return
    fi

    source "$CONFIG_FILE"

    if [[ -f "$RESTIC_PASSWORD_FILE" ]]; then
        export RESTIC_PASSWORD=$(< "$RESTIC_PASSWORD_FILE")
    else
        log "Restic password file not found at $RESTIC_PASSWORD_FILE"
        exit 1
    fi

    REPO="rclone:${REMOTE_NAME}:${REPO_PATH}"
    TAG="cloud-${TIMESTAMP}"

    log "Starting encrypted restic backup to $REPO"
    restic -r "$REPO" backup "$BACKUP_SOURCE" \
	--pack-size 8 \
        --exclude /dev --exclude /proc --exclude /sys \
        --exclude /tmp --exclude /run --exclude /mnt \
        --exclude /media --exclude /lost+found \
        --tag "$TAG"

    log "Pruning old snapshots..."
    restic -r "$REPO" forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

    log "Cloud backup complete."
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    log "=== BACKUP START: $TIMESTAMP ==="
    check_dependencies
    install_timeshift
    detect_filesystem
    create_timeshift_snapshot
    run_cloud_backup
    log "=== BACKUP COMPLETE ==="
}

main "$@"
