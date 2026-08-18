# Hardware profile, hand-written from a live inspection of the machine.
#
# On install day `nixos-generate-config` will produce its own version of this
# file. You can either paste that one over this, or keep this and just check the
# module lists agree — everything here was read off the running hardware, so it
# should already be right. Filesystems deliberately live in ./disks.nix instead.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  # nvme  — both SN850X
  # xhci_pci / usbhid — Kraken, Lian Li hub, Elgato, keyboard/mouse
  # ahci / sd_mod / usb_storage — install media and any SATA disk
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [];
  boot.extraModulePackages = [];

  # kvm-amd: virtualisation on Zen 4.
  boot.kernelModules = ["kvm-amd"];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # 7950X3D — Zen 4, x86-64-v4 capable.
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;

  # MT7922 Wi-Fi 6E and the RTL8125 2.5 GbE both need firmware, and both are in
  # linux-firmware, which this pulls in.
  #
  # NOT enableAllFirmware: that adds the non-redistributable blobs too —
  # facetimehd (a MacBook camera), b43 (old Broadcom Wi-Fi), broadcom-bt and the
  # Xbox wireless dongle. None of that exists in this machine, and every one of
  # them has to be zstd-recompressed locally because the unfree bits are not in
  # the binary cache.
  hardware.enableRedistributableFirmware = true;
}
