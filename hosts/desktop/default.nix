# The one real machine: MSI MAG X670E Carbon WiFi / Ryzen 9 7950X3D / RTX 4090 /
# 64 GB DDR5 / 2× WD SN850X (1 TB + 2 TB) in a single btrfs pool.
{...}: {
  imports = [
    ./hardware-configuration.nix
    ./disks.nix

    # Common to every host
    ../../modules/nixos

    # Hardware and use-case specific to this box
    ../../modules/nixos/cpu.nix # 7950X3D: amd_pstate, V-Cache scheduling
    ../../modules/nixos/nvidia.nix # RTX 4090, open kernel modules
    ../../modules/nixos/capture.nix # Elgato 4K X
    ../../modules/nixos/liquidctl.nix # Kraken pump + Lian Li fans
    ../../modules/nixos/gaming.nix # Steam, gamescope, gamemode, ProtonPlus
  ];

  networking.hostName = "julien-desktop";

  # The NixOS release this host was FIRST installed with. Never change it on an
  # existing install — it is a compatibility marker for stateful services, not a
  # version to keep current.
  system.stateVersion = "26.05";
}
