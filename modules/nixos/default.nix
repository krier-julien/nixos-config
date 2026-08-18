# The system modules that are true of ANY machine running this config — the
# desktop, and the VM used to test it.
#
# Hardware-specific modules (./cpu.nix, ./nvidia.nix, ./capture.nix,
# ./liquidctl.nix) and the games stack (./gaming.nix) are imported by
# ../../hosts/desktop instead, so the VM doesn't try to talk to a 4090, a
# Kraken, or a capture card that aren't there.
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
