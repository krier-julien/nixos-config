{...}: {
  imports = [
    ./caelestia.nix
    ./hyprland.nix
    ./theme.nix

    ./programs/apps.nix
    ./programs/shell.nix
    ./programs/terminal.nix
    ./programs/obs.nix

    ./services/elgato-monitor.nix
    ./services/nxapi.nix
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
