# The Caelestia shell — bar, launcher, dashboard, notifications, lock screen,
# and the Material You colour generation that recolours everything from the
# wallpaper.
#
# This uses the OFFICIAL flake (github:caelestia-dots/shell) via its own
# home-manager module. Deliberately NOT one of the community "full dots" ports:
# those bundle a Hyprland config too, and the one that ports it most completely
# is archived and self-described as very experimental. Here Caelestia owns the
# shell, and ./hyprland.nix — which is yours, in this repo — owns the compositor.
{inputs, ...}: {
  imports = [inputs.caelestia-shell.homeManagerModules.default];

  programs.caelestia = {
    enable = true;

    # Adds the `caelestia` CLI to PATH: screenshot, record, clipboard, emoji,
    # wallpaper, scheme. The Hyprland keybinds in ./hyprland.nix call it.
    cli.enable = true;

    # Run the shell as a systemd user service rather than an exec-once. It then
    # restarts on crash and you get `journalctl --user -u caelestia` when
    # something goes wrong, which an exec-once gives you neither of.
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };

    # Written to ~/.config/caelestia/shell.json. Everything not listed keeps
    # Caelestia's own default.
    settings = {
      bar = {
        status = {
          showAudio = true;
          showBattery = false; # desktop
          showBluetooth = true;
          showNetwork = true;
        };
        workspaces = {
          shown = 10;
          activeIndicator = true;
          showWindows = true;
        };
      };

      general.apps = {
        terminal = ["foot"];
        browser = ["brave-origin"];
        explorer = ["thunar"];
        audio = ["pwvucontrol"];
      };

      # Material You palette derived live from the wallpaper.
      appearance.palette.autoMode = true;

      lock.recolourLogo = true;

      services = {
        # 24-hour clock, matching the fr_LU locale.
        useTwelveHourClock = false;
        # Weather needs a location; left off rather than shipping a placeholder
        # that silently reports the wrong city.
        weatherLocation = "";
      };
    };

    cli.settings = {
      theme = {
        enableTerm = true;
        enableHypr = true;
        enableDiscord = true;
        enableFuzzel = true;
        enableBtop = true;
        enableGtk = true;
        enableQt = true;
        # Spicetify/Zed/Warp/Chromium theming — nothing here uses them.
        enableSpicetify = false;
        enableZed = false;
        enableWarp = false;
        enableChromium = false;
        iconTheme = "Papirus-Dark";
      };
    };
  };

  # Wallpapers. `caelestia wallpaper` reads from here and regenerates the whole
  # colour scheme from whichever one you pick.
  home.file."Images/wallpapers/.keep".text = "";
}
