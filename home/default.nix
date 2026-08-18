# The desktop's home-manager entry point: everything in ./common.nix, plus the
# apps and the two hardware-bound user services.
{...}: {
  imports = [
    ./common.nix

    ./programs/apps.nix
    ./programs/obs.nix

    ./services/elgato-monitor.nix
    ./services/nxapi.nix
  ];
}
