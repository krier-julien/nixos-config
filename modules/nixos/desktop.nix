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

  # ── Login manager: SDDM + the astronaut theme ────────────────────────────
  # Caelestia ships no greeter and its README suggests greetd/tuigreet, which is
  # lighter. SDDM is the deliberate choice here: the login screen is the first
  # thing you see and a text prompt in front of a riced desktop looks unfinished.
  #
  # Caveat worth knowing: Caelestia's Material You colours do NOT reach any
  # greeter — it is a separate, statically themed component that runs before
  # your session exists. Continuity comes from pointing the theme at the same
  # wallpaper, not from the colour engine.
  services.displayManager.sddm = {
    enable = true;

    # Run the greeter itself as a Wayland session. On an NVIDIA box whose only
    # session is Wayland, this avoids standing up an entire X server purely to
    # draw a login box, and makes the handoff into Hyprland a Wayland→Wayland
    # transition rather than a server teardown.
    wayland.enable = true;

    theme = "sddm-astronaut-theme";

    # The theme is Qt6/QML and needs these at runtime. Without them SDDM starts,
    # fails to load the QML, and falls back to a blank screen — the classic
    # "SDDM boots to black" symptom.
    #
    # qtmultimedia is the load-bearing one now that the theme is an ANIMATED
    # preset: the background is an mp4 played by a QML MediaPlayer, and without
    # this module the greeter renders a black rectangle where the video should
    # be (NixOS/nixpkgs#390251). Qt 6 plays it through its FFmpeg backend, which
    # is what nixpkgs builds by default — no GStreamer plugins needed.
    extraPackages = with pkgs.kdePackages; [
      qtsvg
      qtmultimedia
      qtvirtualkeyboard
    ];

    settings = {
      # Numlock on at the login prompt, matching the Hyprland input config.
      General.Numlock = "on";
    };
  };

  # ── The uwsm trap ────────────────────────────────────────────────────────
  # Unlike tuigreet — where the session is hardcoded into the greeter's --cmd —
  # SDDM shows a session picker, and programs.hyprland.withUWSM installs TWO
  # entries: "hyprland" and "hyprland-uwsm". Picking the plain one starts
  # Hyprland outside a systemd user session, graphical-session.target is never
  # reached, and nxapi.service silently never starts.
  #
  # This pre-selects the correct one. SDDM also remembers the last session per
  # user, so after the first login it stays picked — but if the Switch presence
  # ever stops working, THIS is the first thing to check.
  services.displayManager.defaultSession = "hyprland-uwsm";

  # ── Never sleep on a timer ───────────────────────────────────────────────
  # logind is the *other* thing that can suspend a machine on idle, separately
  # from anything the desktop does. `ignore` is already the NixOS default, so
  # this line changes nothing today — it is here so that the intent is written
  # down in one place with the shell's idle config (../../home/caelestia.nix,
  # `general.idle`), and so a future change to the default cannot quietly put
  # the box to sleep mid-download.
  #
  # This disables the idle TIMER, not suspend itself: `systemctl suspend` and
  # the session menu still work. To remove the capability outright it would be
  # `systemd.targets.sleep.enable = false` and its three siblings — not done,
  # because it would also break the liquidctl resume hook in ./liquidctl.nix
  # for no benefit.
  services.logind.settings.Login.IdleAction = "ignore";

  # Portals: screen sharing, file pickers, and the "share a window" flow that
  # your OBS→Discord path depends on.
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common.default = ["hyprland" "gtk"];
  };

  # Secret storage. Discord, and anything using libsecret, expects it.
  services.gnome.gnome-keyring.enable = true;
  # Unlock the keyring at login. This must name the ACTUAL greeter — it was
  # `greetd` before the switch to SDDM, and a stale name here means the keyring
  # stays locked and Discord re-prompts for credentials every session.
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Thumbnails and trash support in the file manager.
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [thunar-archive-plugin thunar-volman];
  };

  # gpu-screen-recorder needs a setuid helper to capture on NVIDIA. The NixOS
  # module installs it correctly; installing the bare package does not.
  # `caelestia record` drives this binary.
  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = with pkgs; [
    # --- the SDDM theme ---------------------------------------------------
    # Must be in systemPackages, not merely in sddm.extraPackages: SDDM looks
    # for themes under /run/current-system/sw/share/sddm/themes.
    #
    # embeddedTheme selects one of the bundled presets — change the string and
    # rebuild. Available:
    #   astronaut (default)      black_hole            cyberpunk
    #   hyprland_kath            jake_the_dog          japanese_aesthetic
    #   pixel_sakura             pixel_sakura_static   purple_leaves
    #   post-apocalyptic_hacker
    #
    # Three of them are animated — the background is a bundled mp4 rather than
    # a still: hyprland_kath, pixel_sakura and jake_the_dog. (pixel_sakura_
    # static exists precisely because pixel_sakura is not.) Those need
    # qtmultimedia above; the others do not care.
    (sddm-astronaut.override {embeddedTheme = "hyprland_kath";})

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
    dart-sass # Caelestia shells out to `sass` for its Discord theme
    glib # gdbus, for closing notifications
    papirus-icon-theme
    papirus-folders # folder colour syncing
    hyprpicker # colour picker keybind

    # --- session odds and ends --------------------------------------------
    polkit_gnome # graphical auth prompts
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
