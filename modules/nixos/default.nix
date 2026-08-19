# The system modules that have nothing to do with this specific hardware.
#
# The hardware-bound ones (./cpu.nix, ./nvidia.nix, ./capture.nix,
# ./liquidctl.nix) and the games stack (./gaming.nix) are imported by
# ../../hosts/desktop instead, so the split stays honest: anything in here
# would work on any machine, anything in there needs this one.
{...}: {
  imports = [
    ./boot.nix
    ./networking.nix
    ./locale.nix
    ./users.nix
    ./nix-settings.nix
    ./desktop.nix
    ./audio.nix
    ./fonts.nix
  ];
}
