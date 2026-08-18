# Home-manager for the throwaway test VM.
#
# Deliberately NOT ./default.nix. Left out:
#   - services/elgato-monitor.nix — targets a capture card that isn't there;
#     the service would sit in a restart loop and tell you nothing.
#   - services/nxapi.nix and the nxapi package — nxapi's npmDepsHash is
#     lib.fakeHash until it has been built once, so including it here would
#     fail the VM build for a reason unrelated to what you're testing.
#     Build it on its own instead:  nix build .#nxapi
#   - curseforge — a 133 MB AppImage download that proves nothing in a VM.
#   - Steam/OBS — several GB, and neither can do anything useful without a GPU.
#
# What IS tested: the Caelestia module, the whole Hyprland config, theming,
# fish/starship/foot, and every system module the VM host pulls in.
{pkgs, ...}: {
  imports = [./common.nix];

  home.packages = with pkgs; [
    firefox
    micro
    fastfetch
    eza
    ripgrep
    bat
  ];
}
