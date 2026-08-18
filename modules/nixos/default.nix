# Every system-level module. Split by concern so that when something breaks you
# know which file to open.
{...}: {
  imports = [
    ./boot.nix
    ./cpu.nix
    ./nvidia.nix
    ./networking.nix
    ./locale.nix
    ./users.nix
    ./nix-settings.nix
    ./desktop.nix
    ./audio.nix
    ./capture.nix
    ./gaming.nix
    ./liquidctl.nix
    ./fonts.nix
  ];
}
