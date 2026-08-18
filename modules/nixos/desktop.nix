# Hyprland session, the greeter, portals, and the bits Caelestia's CLI shells
# out to. The *look* is configured per-user in ../../home; this file is only
# what has to exist system-wide.
{pkgs, ...}: {
  programs.hyprland = {
    enable = true;

    # uwsm wraps the compositor in a proper systemd user session. This is not
    # cosmetic: it is what makes `graphical-session.target` actually get reached,
    # and the nxapi user service is bound to that target. Without uwsm the
    # service never starts and the Rich Presence silently does nothing.
    withUWSM = true;

    xwayland.enable = true;
  };

  # greetd + tuigreet: a text greeter, which is what Caelestia's own README
  # recommends. It costs ~0 boot time and cannot fight the shell's theming the
  # way a graphical DM would.
  services.greetd = {
    enable = true;

    # Wires up the tty plumbing a text greeter needs (Type=idle, TTYReset,
    # stdin/stdout on the tty). Doing it by hand instead is how you end up with
    # the greeter's prompt fighting kernel log output for tty1.
    useTextGreeter = true;

    settings.default_session = {
      # Full store paths: the greeter runs as the `greeter` user, whose PATH
      # does not include your session's packages.
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-user-session --asterisks --cmd '${pkgs.uwsm}/bin/uwsm start hyprland-uwsm.desktop'";
      user = "greeter";
    };
  };

  # Portals: screen sharing, file pickers, and the "share a window" flow that
  # your OBS→Discord path depends on.
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common.default = ["hyprland" "gtk"];
  };

  # Secret storage. Discord, and anything using libsecret, expects it.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Thumbnails and trash support in the file manager.
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [thunar-archive-plugin thunar-volman];
  };

  # gpu-screen-recorder needs a setuid helper to capture on NVIDIA. The NixOS
  # module installs it correctly; installing the bare package does not.
  # `caelestia record` drives this binary.
  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = with pkgs; [
    # --- Caelestia CLI runtime dependencies -------------------------------
    # The home-manager module pulls the CLI in, but these are the external
    # programs it shells out to. Missing one produces a confusing "command not
    # found" from inside a keybind, so pin them here.
    libnotify # notifications
    swappy # screenshot editor
    grim # screenshot capture
    slurp # region selection
    wl-clipboard # copy
    cliphist # clipboard history
    fuzzel # clipboard/emoji picker UI
    dart-sass # Discord theming
    glib # gdbus, for closing notifications
    papirus-icon-theme
    papirus-folders # folder colour syncing
    hyprpicker # colour picker keybind

    # --- session odds and ends --------------------------------------------
    polkit_gnome # graphical auth prompts
    gammastep # night light
    brightnessctl
    playerctl
    wev # `wev` — read raw key events when a bind won't fire
    xdg-utils
  ];

  # Qt apps (Caelestia's shell is Quickshell, i.e. Qt) need a platform theme or
  # they fall back to a Fusion look that clashes with everything.
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };
}
