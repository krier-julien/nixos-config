# Home-manager for julien on the desktop. This is the only home entry point —
# everything the user session needs is imported from here.
{...}: {
  imports = [
    ./caelestia.nix # the shell: bar, launcher, lock screen, colours
    ./hyprland.nix # the compositor — ours, not Caelestia's
    ./theme.nix # GTK/Qt/cursor scaffolding for Caelestia to recolour

    ./programs/apps.nix
    ./programs/mangohud.nix
    ./programs/obs.nix
    ./programs/shell.nix
    ./programs/terminal.nix

    ./services/browser-clean-exit.nix
    ./services/elgato-monitor.nix
    ./services/nxapi.nix
  ];

  home.username = "julien";
  home.homeDirectory = "/home/julien";

  # Same rule as system.stateVersion: set once, never bumped.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # French XDG directory names, because the locale is fr_LU and the existing
  # install already has them. Renaming would break every path that points here.
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
