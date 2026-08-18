# Home-manager bits that are the same everywhere — the desktop and the VM used
# to test it. Hardware-bound services (the Elgato loopback, nxapi) and the full
# app set live in ./default.nix, which is the desktop's entry point.
{...}: {
  imports = [
    ./caelestia.nix
    ./hyprland.nix
    ./theme.nix

    ./programs/shell.nix
    ./programs/terminal.nix
  ];

  home.username = "julien";
  home.homeDirectory = "/home/julien";

  # Same rule as system.stateVersion: set once, never bumped.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # XDG user directories. The current machine has French names (Bureau,
  # Téléchargements, …) because the locale is fr_LU; keep them so nothing that
  # already points at those paths breaks.
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "$HOME/Bureau";
    documents = "$HOME/Documents";
    download = "$HOME/Téléchargements";
    music = "$HOME/Musique";
    pictures = "$HOME/Images";
    videos = "$HOME/Vidéos";
    publicShare = "$HOME/Public";
    templates = "$HOME/Modèles";
  };
}
