# Disk layout — a SINGLE btrfs filesystem spanning BOTH NVMe drives.
#
# This mirrors what the machine already runs under CachyOS: one pool, ~2.8 TB
# usable, so nothing ever has to be "put on the other drive". NixOS handles a
# multi-device btrfs with no extra work — the kernel assembles it from the UUID
# and both members are NVMe, so they are present in the initrd.
#
#   nvme0n1  (1 TB SN850X)
#     ├─ p1   4 G   vfat   /boot  (EFI system partition)
#     └─ p2   rest  btrfs  ─┐
#                           ├─ one filesystem, one UUID
#   nvme1n1  (2 TB SN850X)  │   (no partition table — btrfs on the raw device,
#     └─ whole disk  btrfs ─┘    exactly as it is set up today)
#
#   subvolumes:  @  @home  @nix  @log  @snapshots
#
# ─────────────────────────────────────────────────────────────────────────────
# ⚠  READ THIS ONCE, THEN DECIDE
#
# A two-device btrfs with the default `-d single` data profile is NOT redundant.
# Data extents are spread across both drives, so losing EITHER drive loses the
# WHOLE pool — not half of it. `-m raid1` (the mkfs default for multi-device)
# keeps *metadata* mirrored, which means btrfs can still tell you what was lost,
# but it cannot give the files back.
#
# That is the trade you are already living with. It is a perfectly normal choice
# for a gaming/desktop box where everything important is on GitHub or a Plex
# server — just don't mistake it for RAID. If you want the pool to survive a
# dead drive, `mkfs.btrfs -d raid1 -m raid1` instead and you get 1 TB usable
# rather than 2.8 TB (raid1 mirrors, so capacity = 2× the smaller device).
# ─────────────────────────────────────────────────────────────────────────────
{...}: let
  # ⇩⇩ FILL THESE IN ON INSTALL DAY ⇩⇩
  # After mkfs, run:  lsblk -o NAME,FSTYPE,UUID
  # The btrfs UUID is shared by both member devices — that is expected.
  pool = "/dev/disk/by-uuid/dd9b845d-2d13-41bb-bfd8-df324965409f";
  esp = "/dev/disk/by-uuid/DA5C-A0CD";

  # zstd:1 is what the current install uses and it is the right call: level 1 is
  # fast enough to be free on an SN850X while still shrinking /nix noticeably.
  btrfsOpts = subvol: [
    "subvol=${subvol}"
    "compress=zstd:1"
    "noatime"
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];
in {
  fileSystems."/" = {
    device = pool;
    fsType = "btrfs";
    options = btrfsOpts "@";
  };

  fileSystems."/home" = {
    device = pool;
    fsType = "btrfs";
    options = btrfsOpts "@home";
  };

  # /nix is the single biggest consumer on a NixOS box and benefits most from
  # its own subvolume: you can snapshot / rather than the store, and you can
  # send-receive the store separately if you ever want to.
  fileSystems."/nix" = {
    device = pool;
    fsType = "btrfs";
    options = btrfsOpts "@nix";
  };

  # neededForBoot: stage-1 wants somewhere to write before / is fully up.
  fileSystems."/var/log" = {
    device = pool;
    fsType = "btrfs";
    options = btrfsOpts "@log";
    neededForBoot = true;
  };

  fileSystems."/.snapshots" = {
    device = pool;
    fsType = "btrfs";
    options = btrfsOpts "@snapshots";
  };

  fileSystems."/boot" = {
    device = esp;
    fsType = "vfat";
    # The ESP is world-readable by default, which leaks nothing useful but trips
    # up `nix flake check`-style linters. Lock it to root.
    options = ["fmask=0077" "dmask=0077"];
  };

  boot.supportedFilesystems = ["btrfs" "vfat" "ntfs"];

  # Scrub monthly. On a `single` pool this cannot repair data errors, but it will
  # tell you a drive is going bad while you still have time to copy things off —
  # which is the entire value of running it on a non-redundant pool.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = ["/"];
  };

  # 64 GB of RAM means a swap *partition* is pointless; zram gives you a
  # compressed overflow that costs nothing when unused. 25 % ≈ 16 GB of zram,
  # which decompresses to rather more. No hibernation (there is no disk swap to
  # hibernate into — say so out loud rather than discovering it later).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };
}
