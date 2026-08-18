# A throwaway VM for testing this config before touching the real machine.
#
# What it proves: that the flake EVALUATES, that everything BUILDS, that the
# boot chain works, that greetd comes up, and that the Caelestia + Hyprland
# home-manager config applies cleanly.
#
# What it cannot prove: anything involving the 4090, the Elgato, the Kraken or
# the Lian Li hub — none of which exist in a VM. Those modules are simply not
# imported here (see ../desktop/default.nix, which does import them).
#
# ⚠ HYPRLAND WILL NOT START UNDER VIRTUALBOX. VBoxSVGA/VMSVGA do not expose a
# DRM render node that Hyprland's backend (aquamarine) can open, so you get
# "no DRM devices found" and the session dies immediately. That is a VirtualBox
# limitation, NOT a bug in this config. Under VirtualBox you are testing
# everything up to and including the tuigreet login prompt.
# For a session that actually renders, use QEMU with virtio-gpu — see
# ../../docs/TESTING.md.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/nixos
  ];

  networking.hostName = "nixos-vm";
  system.stateVersion = "26.05";

  # ── Disks ────────────────────────────────────────────────────────────────
  # Mounted by LABEL, not UUID, so this host needs no editing at all — the
  # labels are set by the mkfs commands in ../../docs/TESTING.md. A single
  # virtual disk with the same subvolume names as the real machine, so the
  # layout is exercised even though the two-device pool is not.
  boot.initrd.availableKernelModules = [
    "ahci"
    "sd_mod"
    "sr_mod"
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "xhci_pci"
  ];
  boot.supportedFilesystems = ["btrfs" "vfat"];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = ["subvol=@" "compress=zstd:1" "noatime"];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = ["subvol=@home" "compress=zstd:1" "noatime"];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = ["subvol=@nix" "compress=zstd:1" "noatime"];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];
  zramSwap.enable = true;

  # ── VM adjustments ───────────────────────────────────────────────────────
  # Plymouth on a virtual framebuffer just hides the boot messages you actually
  # want to read when something fails.
  boot.plymouth.enable = lib.mkForce false;
  boot.kernelParams = lib.mkForce ["console=tty0"];
  boot.initrd.verbose = lib.mkForce true;
  boot.consoleLogLevel = lib.mkForce 4;

  # VirtualBox guest additions (clipboard, resize). Left off by default because
  # it builds an out-of-tree kernel module and can break on a kernel bump —
  # which would be a VirtualBox failure masquerading as a config failure.
  # Uncomment if you want shared folders:
  # virtualisation.virtualbox.guest.enable = true;

  # Guest integration: clipboard sharing, resizing, shared folders.
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  # A VM has no Wi-Fi; iwd would just log errors every boot.
  networking.networkmanager.wifi.backend = lib.mkForce "wpa_supplicant";
  hardware.bluetooth.enable = lib.mkForce false;

  # ── `nix build .#nixosConfigurations.nixos-vm.config.system.build.vm` ────
  # This is the good way to test. Nix builds a QEMU VM *and pulls QEMU in as
  # part of the closure*, so you do not have to install it on the host. Unlike
  # VirtualBox, virtio-gpu exposes a real DRM render node, so Hyprland and
  # Caelestia actually render.
  #
  # The settings here apply ONLY to that VM image, never to a real install.
  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192; # MB — Quickshell wants room
    cores = 6;
    diskSize = 32768; # MB — /nix fills up fast with Qt in it
    graphics = true;

    # virtio-vga-gl gives the guest a DRM node with GL passthrough to the host
    # 4090. If the VM refuses to start with a GL error, drop back to plain
    # "-device virtio-vga" and "-display gtk" — you lose acceleration and
    # Hyprland will be sluggish, but it still comes up.
    qemu.options = [
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };

  # Let yourself in without typing a password into a throwaway machine.
  users.users.julien.initialPassword = "nixos";
  users.users.root.initialPassword = "nixos";
  security.sudo.wheelNeedsPassword = false;
}
