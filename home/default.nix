# The desktop's home-manager entry point: everything in ./common.nix, plus the
# apps and the user services — the two hardware-bound ones, and the shutdown
# hook that lets Brave save its session before the session goes away.
{...}: {
  imports = [
    ./common.nix

    ./programs/apps.nix
    ./programs/mangohud.nix
    ./programs/obs.nix

    ./services/browser-clean-exit.nix
    ./services/elgato-monitor.nix
    ./services/nxapi.nix
    ./services/wallpaper-video.nix
  ];
}
