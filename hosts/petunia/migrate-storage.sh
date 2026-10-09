#!/usr/bin/env bash
# One-time live storage migration for petunia (run as root, inside tmux).
#
#   Micron 2400: shrink NTFS "Data", add an XFS "hub" partition, move the HF hub cache.
#   Windows backup: Users/ddukes (junk excluded) -> ZFS dataset petunia/backup.
#   Phison E12: wipe, one XFS "models" partition, move the model containers.
#
# Never touches the Micron swap partition (p2). No reboot, no nixos-rebuild.
# Every subcommand is guarded by by-id/size/fstype checks and is safe to re-run.
# Design record: debug/petunia-model-drive.md. Fileystem wiring: modules/hardware/petunia/.
set -euo pipefail

MICRON=/dev/disk/by-id/nvme-MTFDKBA2T0QFM-1BD1AABGA_214031EE642B
PHISON=/dev/disk/by-id/nvme-PCIe_SSD_21020151200034
SWAP_PARTUUID=5eacdc8e-39ba-435a-8283-bb0e290e7846
DATA_PARTUUID=bca918b2-b6b2-4745-9a71-b4dead9badd5
WIN_PARTUUID=e48695b4-d211-4442-a9db-aac535c0b01c
HF=/data/huggingface
MNT=/mnt/mig
BACKUP_DIR=/root/storage-migration

die() { echo "ABORT: $*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }
run() { printf '+ %s\n' "$*"; "$@"; }
confirm() { read -r -p "$1 [type YES] " a; [[ $a == YES ]] || die "not confirmed"; }

# Re-exec once inside a nix shell that provides every tool (no system rebuild).
if [[ -z ${MIG_IN_NIX:-} ]]; then
  [[ $EUID -eq 0 ]] || die "run as root"
  exec env MIG_IN_NIX=1 nix shell \
    nixpkgs#ntfs3g nixpkgs#xfsprogs nixpkgs#gptfdisk nixpkgs#parted \
    nixpkgs#rsync nixpkgs#util-linux nixpkgs#psmisc \
    -c bash "$(readlink -f "$0")" "$@"
fi
mkdir -p "$BACKUP_DIR" "$MNT"

part() { echo "$1-part$2"; }  # by-id partition path
partuuid_of() { blkid -s PARTUUID -o value "$(readlink -f "$1")"; }
sector_info() { sgdisk -i "$2" "$1"; }  # disk, partnum
sgfield() { sector_info "$1" "$2" | sed -n "s/^$3: *//p" | head -1; }

require_swap_intact() {
  [[ $(partuuid_of "$(part "$MICRON" 2)") == "$SWAP_PARTUUID" ]] || die "Micron p2 is not the swap partition"
}

# -------------------------------------------------------------------------
cmd_preflight() {
  say "Devices"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS,PARTUUID "$MICRON" "$PHISON"
  [[ $(blockdev --getsize64 "$MICRON") -gt 1900000000000 ]] || die "Micron size unexpected"
  [[ $(blockdev --getsize64 "$PHISON") -lt 520000000000 ]] || die "Phison size unexpected"
  require_swap_intact
  [[ $(partuuid_of "$(part "$MICRON" 1)") == "$DATA_PARTUUID" ]] || die "Micron p1 is not the NTFS Data partition"
  [[ $(partuuid_of "$(part "$PHISON" 4)") == "$WIN_PARTUUID" ]] || die "Phison p4 is not the Windows partition"
  findmnt -rn -S "$(readlink -f "$(part "$MICRON" 1)")" && die "Data is mounted"

  say "GPT backups -> $BACKUP_DIR"
  run sgdisk --backup="$BACKUP_DIR/micron-gpt.bak" "$MICRON"
  run sgdisk --backup="$BACKUP_DIR/phison-gpt.bak" "$PHISON"
  sgdisk -p "$MICRON" >"$BACKUP_DIR/micron-gpt.txt"
  sgdisk -p "$PHISON" >"$BACKUP_DIR/phison-gpt.txt"

  say "Micron free regions (sectors)"
  parted -m "$MICRON" unit s print free | grep free || true

  say "NTFS Data: resize info"
  ntfsresize --info --force --no-progress-bar "$(part "$MICRON" 1)" || true

  say "NTFS Data: contents (read-only mount)"
  mkdir -p "$MNT/data"
  mount -t ntfs3 -o ro "$(part "$MICRON" 1)" "$MNT/data" || die "ro mount of Data failed (dirty? run: ntfsfix -d <dev>)"
  df -h "$MNT/data"
  du -h --max-depth=1 "$MNT/data" 2>/dev/null | sort -h | tail -15
  umount "$MNT/data"
  say "Preflight done. Next: shrink-data <new-size-GiB>"
}

# -------------------------------------------------------------------------
cmd_shrink_data() {
  local gib=${1:?usage: shrink-data <new Data size in GiB>}
  local dev; dev=$(part "$MICRON" 1)
  require_swap_intact
  [[ $(partuuid_of "$dev") == "$DATA_PARTUUID" ]] || die "p1 is not Data"
  findmnt -rn -S "$(readlink -f "$dev")" && die "Data is mounted"
  [[ -s $BACKUP_DIR/micron-gpt.bak ]] || die "run preflight first (GPT backup)"

  local start type guid name
  start=$(sgfield "$MICRON" 1 "First sector" | awk '{print $1}')
  type=$(sgfield "$MICRON" 1 "Partition GUID code" | awk '{print $1}')
  guid=$(sgfield "$MICRON" 1 "Partition unique GUID")
  name=$(sed -n "s/^Partition name: *'\(.*\)'/\1/p" <(sector_info "$MICRON" 1))
  [[ $type == EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 ]] || die "p1 type is not Microsoft basic data ($type)"

  local bytes=$((gib * 1024 * 1024 * 1024))
  say "Checking NTFS consistency"
  ntfsresize --check --force --no-progress-bar "$dev" || die "NTFS check failed; if dirty/hibernated: ntfsfix -d $dev, then retry"
  say "Dry run: shrink to ${gib} GiB"
  ntfsresize --no-action --force --size "$bytes" "$dev" || die "dry run refused (below minimum size?)"

  echo "About to shrink NTFS Data to ${gib} GiB. Power loss during this step can corrupt Data."
  confirm "Proceed with REAL ntfsresize?"
  run ntfsresize --force --force --no-progress-bar --size "$bytes" "$dev"
  run ntfsresize --check --force --no-progress-bar "$dev"

  say "Shrinking the partition (same start/PARTUUID/type), 1 MiB slack"
  local end=$(( start + (bytes + 1048576) / 512 - 1 ))
  end=$(( (end + 1) / 2048 * 2048 - 1 ))   # end on a MiB boundary
  run sgdisk -d 1 -n "1:${start}:${end}" -t 1:0700 -u "1:${guid}" -c "1:${name:-Data}" "$MICRON"
  run partx -u --nr 1 "$MICRON"
  udevadm settle
  [[ $(partuuid_of "$dev") == "$DATA_PARTUUID" ]] || die "p1 PARTUUID changed"
  require_swap_intact

  say "Grow the filesystem to fill its partition, then re-check"
  run ntfsresize --force --force --no-progress-bar "$dev"
  run ntfsresize --check --force --no-progress-bar "$dev"
  mount -t ntfs3 -o ro "$dev" "$MNT/data"; ls "$MNT/data" | head; df -h "$MNT/data"; umount "$MNT/data"
  say "Done. Free regions:"; parted -m "$MICRON" unit s print free | grep free
}

# -------------------------------------------------------------------------
# new_partition <disk> <label> <size-GiB|max>  -> creates GPT partition + xfs, prints dev
new_xfs_partition() {
  local disk=$1 label=$2 gib=$3 fs_start fs_end best=0 n
  # Largest free region, MiB aligned.
  while IFS=: read -r _ s e _; do
    s=${s%s}; e=${e%s}
    local len=$(( e - s + 1 ))
    (( len > best )) && { best=$len; fs_start=$s; fs_end=$e; }
  done < <(parted -m "$disk" unit s print free | grep ':free;')
  (( best > 0 )) || die "no free region on $disk"
  fs_start=$(( (fs_start + 2047) / 2048 * 2048 ))
  fs_end=$(( (fs_end + 1) / 2048 * 2048 - 1 ))
  if [[ $gib != max ]]; then
    local want=$(( fs_start + gib * 2097152 - 1 ))
    (( want <= fs_end )) || die "largest free region is only $(( (fs_end-fs_start+1) / 2097152 )) GiB"
    fs_end=$want
  fi
  n=$(( $(sgdisk -p "$disk" | awk '/^ +[0-9]+ /{m=$1} END{print m+0}') + 1 ))
  run sgdisk -n "${n}:${fs_start}:${fs_end}" -t "${n}:8300" -c "${n}:${label}" "$disk"
  run partx -a --nr "$n" "$disk" || run partx -u --nr "$n" "$disk"
  udevadm settle
  local dev; dev=$(part "$disk" "$n")
  for _ in $(seq 20); do [[ -b $dev ]] && break; sleep 0.5; done
  [[ -b $dev ]] || die "$dev did not appear"
  run mkfs.xfs -f -L "$label" "$dev"
  echo "$dev"
}

cmd_make_hub() {
  local gib=${1:?usage: make-hub <GiB>}
  require_swap_intact
  say "Largest free region will be used"; parted -m "$MICRON" unit s print free | grep free
  confirm "Create ${gib} GiB XFS 'hub' partition on the Micron?"
  local dev; dev=$(new_xfs_partition "$MICRON" hub "$gib" | tail -1)
  say "Created $dev (PARTUUID $(partuuid_of "$dev")) — record it for nix"
  sgdisk -p "$MICRON"
  require_swap_intact
}

# -------------------------------------------------------------------------
# copy <name> <label> : rsync $HF/<name> -> labelled xfs, then verify with a checksum dry run
copy_to() {
  local name=$1 label=$2 dev="/dev/disk/by-label/$2" mp="$MNT/$2"
  [[ -b $dev ]] || die "no filesystem labelled $label"
  [[ $(blkid -s TYPE -o value "$dev") == xfs ]] || die "$label is not xfs"
  mkdir -p "$mp"; findmnt -rn "$mp" >/dev/null || run mount -o noatime "$dev" "$mp"
  findmnt -rn "$HF/$name" -t xfs >/dev/null && die "$HF/$name is already the new filesystem"
  fuser -vm "$HF/$name" 2>&1 | grep -q . && { fuser -vm "$HF/$name"; die "processes hold $HF/$name; stop them first"; } || true
  need=$(du -sB1 "$HF/$name" | cut -f1); avail=$(df -B1 --output=avail "$mp" | tail -1)
  (( need < avail )) || die "$HF/$name ($need B) does not fit on $label ($avail B)"
  run rsync -aHAX --info=progress2 "$HF/$name/" "$mp/"
  say "Verify (checksum dry run; any itemized line is a difference)"
  local diff; diff=$(rsync -aHAXnci "$HF/$name/" "$mp/" | grep -v '^\.d' || true)
  [[ -z $diff ]] || { echo "$diff" | head -20; die "verify found differences"; }
  echo "verified: $name -> $label identical"
}

# swap_in <name> <label> : move pool copy aside, leave an empty mountpoint, unmount temp
swap_in() {
  local name=$1 label=$2
  fuser -vm "$HF/$name" 2>&1 | grep -q . && die "processes hold $HF/$name"
  [[ ! -e $HF/$name.old ]] || die "$HF/$name.old already exists"
  run mv "$HF/$name" "$HF/$name.old"
  run mkdir "$HF/$name"
  run umount "$MNT/$label"
  echo "Pool copy kept at $HF/$name.old. After nix mounts the new fs: verify, then delete .old."
}

cmd_copy_hub() { copy_to hub hub; }
cmd_finish_hub() { swap_in hub hub; }
cmd_copy_models() { copy_to models models; }
cmd_finish_models() { swap_in models models; }

# -------------------------------------------------------------------------
cmd_backup() {
  local mode=${1:-estimate}   # estimate | run | verify
  local dev; dev=$(part "$PHISON" 4)
  [[ $(partuuid_of "$dev") == "$WIN_PARTUUID" ]] || die "Phison p4 is not the Windows partition"
  mkdir -p "$MNT/win"
  findmnt -rn "$MNT/win" >/dev/null || run mount -t ntfs3 -o ro "$dev" "$MNT/win"
  local src="$MNT/win/Users/ddukes"
  [[ -d $src ]] || die "$src not found"
  local dst=/backup/windows-ddukes
  local ex=(
    --exclude='AppData/Local/Temp' --exclude='AppData/Local/CrashDumps'
    --exclude='AppData/Local/D3DSCache' --exclude='AppData/Local/Packages'
    --exclude='AppData/Local/Microsoft/Windows/INetCache'
    --exclude='AppData/Local/Microsoft/Windows/WebCache'
    --exclude='AppData/Local/Microsoft/Windows/Explorer'
    --exclude='AppData/Local/*/*/Cache' --exclude='AppData/Local/*/*/Code Cache'
    --exclude='AppData/Local/*/*/GPUCache' --exclude='AppData/Local/*/*/Service Worker/CacheStorage'
    --exclude='AppData/Roaming/*/Cache' --exclude='AppData/Roaming/*/Code Cache'
    --exclude='AppData/Roaming/*/GPUCache' --exclude='AppData/Roaming/*/Service Worker/CacheStorage'
    --exclude='Application Data' --exclude='Local Settings' --exclude='My Documents'
    --exclude='Cookies' --exclude='NetHood' --exclude='PrintHood' --exclude='Recent'
    --exclude='SendTo' --exclude='Start Menu' --exclude='Templates'
    --exclude='NTUSER.DAT.LOG*' --exclude='ntuser.dat.LOG*' --exclude='*.tmp' --exclude='*.etl'
    --exclude='$Recycle.Bin' --exclude='.git/objects/pack/*.tmp'
  )
  case $mode in
    estimate)
      mkdir -p /dev/shm/_est
      say "Estimated transfer (junk excluded)"
      rsync -rtn --stats -l "${ex[@]}" "$src/" /dev/shm/_est/ 2>&1 | grep -E 'Number of files|Total file size'
      say "Pool free space"; zfs list -o name,avail petunia/data
      ;;
    run)
      zfs list petunia/backup >/dev/null 2>&1 || run zfs create -o compression=zstd -o recordsize=128K -o mountpoint=/backup petunia/backup
      mkdir -p "$dst"
      run rsync -rtl --info=progress2 --chown=ddukes:users "${ex[@]}" "$src/" "$dst/"
      ;;
    verify)
      say "Second pass must list nothing"
      local d; d=$(rsync -rtlnci "${ex[@]}" "$src/" "$dst/" | grep -v '^\.d' || true)
      [[ -z $d ]] || { echo "$d" | head; die "backup differs from source"; }
      (cd "$dst" && find . -type f -print0 | sort -z | xargs -0 sha256sum >/backup/windows-ddukes.SHA256SUMS)
      run zfs snapshot "petunia/backup@verified-$(date +%Y%m%d)"
      echo "Backup verified: $(find "$dst" -type f | wc -l) files, $(du -sh "$dst" | cut -f1)."
      echo "Inspect $dst yourself before running: phison-wipe"
      ;;
    *) die "backup [estimate|run|verify]" ;;
  esac
}

# -------------------------------------------------------------------------
cmd_phison_wipe() {
  [[ $(partuuid_of "$(part "$PHISON" 4)") == "$WIN_PARTUUID" ]] || die "Phison layout changed"
  zfs list -H -t snapshot -o name | grep -q '^petunia/backup@verified-' || die "no verified backup snapshot"
  [[ -s /backup/windows-ddukes.SHA256SUMS ]] || die "no backup manifest"
  findmnt -rn "$MNT/win" >/dev/null && run umount "$MNT/win"
  lsblk -no MOUNTPOINTS "$PHISON" | grep -q . && die "Phison has mounted partitions"
  echo "This DESTROYS Windows on $PHISON (477 GiB). GPT backup: $BACKUP_DIR/phison-gpt.bak"
  confirm "Wipe the Phison and create one XFS 'models' partition?"
  run wipefs -a "$(part "$PHISON" 1)" "$(part "$PHISON" 2)" "$(part "$PHISON" 4)" "$(part "$PHISON" 5)" || true
  run sgdisk --zap-all "$PHISON"
  run blkdiscard -f "$PHISON" || true
  run partprobe "$PHISON"; udevadm settle
  local dev; dev=$(new_xfs_partition "$PHISON" models max | tail -1)
  say "Created $dev (PARTUUID $(partuuid_of "$dev")) — record it for nix"
}

case ${1:-} in
  preflight)      shift; cmd_preflight "$@" ;;
  shrink-data)    shift; cmd_shrink_data "$@" ;;
  make-hub)       shift; cmd_make_hub "$@" ;;
  copy-hub)       shift; cmd_copy_hub "$@" ;;
  finish-hub)     shift; cmd_finish_hub "$@" ;;
  backup)         shift; cmd_backup "$@" ;;
  phison-wipe)    shift; cmd_phison_wipe "$@" ;;
  copy-models)    shift; cmd_copy_models "$@" ;;
  finish-models)  shift; cmd_finish_models "$@" ;;
  *) sed -n '2,8p' "$0"; echo; echo "usage: $0 preflight | shrink-data <GiB> | make-hub <GiB> | copy-hub | finish-hub | backup [estimate|run|verify] | phison-wipe | copy-models | finish-models"; exit 2 ;;
esac
