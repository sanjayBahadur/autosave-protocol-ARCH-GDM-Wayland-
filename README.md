# MALCOM Autosave Protocol

A fully automated snapshot and encrypted cloud backup system for Arch Linux systems (GNOME/Wayland-safe), designed for those who have better things to do than rebuild their system from scratch at 3 AM.

---

## Why This Exists

Because one fateful night, I wiped my system clean with a single misstep. After recovering from that disaster, I decided never again. This project was born out of frustration, necessity, and the realization that "I'll back it up later" is not a recovery strategy.

This script exists to:

* Automate system-level backups using Timeshift.
* Create secure, encrypted, deduplicated backups using Restic.
* Upload those backups to Google Drive using Rclone.
* Handle API limits, retries, and weird cloud behavior with grace.
* Prune old backups with intelligent rules so your cloud doesn't become a landfill.

---

## Features

* Creates Timeshift snapshots (RSYNC or BTRFS).
* Encrypts and uploads backups using Restic + Rclone.
* Supports rate-limiting and retries to avoid Google quota errors.
* Automatically prunes old backups using daily/weekly/monthly retention.
* Configurable, scriptable, Wayland-friendly.

---

## Project Structure

```
.
├── autosave.sh          # Main automation script
├── autosave.conf        # User configuration
└── ~/.config/restic/password  # Your encryption key (guard it!)
```

---

## One-Time Setup

### Step 1: Install Dependencies

```bash
sudo pacman -Syu timeshift restic rclone
```

### Step 2: Configure Rclone for Google Drive

```bash
rclone config
```

* Remote name: `myremote`
* Storage: `drive`
* Scope: `1` (Full access)
* OAuth credentials: use default or paste your own (recommended)

### Step 3: Initialize Restic Repository

```bash
export RESTIC_PASSWORD="your-super-secure-password"
restic -r rclone:myremote:Backups/ResticVault init
```

### Step 4: Save the Password

```bash
mkdir -p ~/.config/restic
echo "your-super-secure-password" > ~/.config/restic/password
chmod 600 ~/.config/restic/password
```

### Step 5: Configure `autosave.conf`

```conf
REMOTE_NAME="myremote"
REPO_PATH="Backups/ResticVault"
RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
BACKUP_SOURCE="/home/sanjay"
```

---

## Running the Backup

```bash
./autosave.sh
```

It will:

1. Create a Timeshift snapshot.
2. Encrypt and upload your files to cloud storage.
3. Prune old backups with retention policy.

---

## Configuration Details

### autosave.conf

```conf
REMOTE_NAME        # rclone remote name
REPO_PATH          # Path inside cloud storage
RESTIC_PASSWORD_FILE  # Path to your Restic password file
BACKUP_SOURCE      # Path to the directory you want to back up
```

### rclone.conf (add manually under \[myremote])

```ini
[myremote]
type = drive
scope = drive
tpslimit = 4
retries = 10
low_level_retries = 20
```

These parameters reduce Google API spam and make the whole thing less fragile.

---

## Restoring From Disaster

If you wiped your system (like I did):

### Restore Timeshift Snapshot

```bash
sudo timeshift --restore
```

### Restore Cloud Backup

```bash
export RESTIC_PASSWORD=$(< ~/.config/restic/password)
restic -r rclone:myremote:Backups/ResticVault snapshots
restic -r rclone:myremote:Backups/ResticVault restore latest --target /tmp/restore
```

---

## Retention Policy

Configured via Restic's `forget` system. The script currently runs:

```bash
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
```

This keeps:

* 1 snapshot per day for 7 days
* 1 snapshot per week for 4 weeks
* 1 snapshot per month for 6 months

You may tweak this depending on how much cloud space you’ve got to burn.

---

## Known Limitations

* Google Drive quotas still exist. We're not Google.
* Timeshift with RSYNC is slow. BTRFS is better.
* You may still want to test restores regularly. Backups that haven’t been tested aren’t backups.

---

## License

MIT. Do what you want with it — just don’t blame me if you delete your own `/boot`.

---

## Final Words

This project was born from a catastrophic mistake and rebuilt into a resilient failsafe. It’s minimal, sharp, and does its job without needing a GUI, cloud dashboard, or emoji.

If you’re serious about backups, this is your starting point. Automate it. Audit it. Own it.
