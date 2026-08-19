# ── Steam and the 4K TV ─────────────────────────────────────────────────────
# The desktop client used to come up at half size on the LG G3. What fixes it
# is one environment variable, and it is NOT set from this file — see
# `sessionEnv` in ../../home/hyprland.nix:
#
#     GDK_SCALE=2
#
# Valve added a 2× client UI for HiDPI in 2018 and wired it to exactly that
# variable. It looks like a GTK setting and Steam's UI is CEF, not GTK, which
# is why it is easy to write off — but Steam reads it itself, independently of
# any toolkit.
#
# The variable has to reach Steam by every launch path, not just one. Hyprland's
# `hl.env` covers the processes Hyprland spawns; an app started from Caelestia's
# launcher is a child of a systemd user service instead and sees only the user
# manager's environment. That is why Steam scaled when it autostarted at login
# and came up half-size when relaunched by hand. Both paths now agree, because
# the same attrset is written to ~/.config/environment.d as well.
#
# The dead ends, written down so they are not rediscovered:
#
#   * The compositor cannot scale it. Steam is an X11 client, and
#     `xwayland.force_zero_scaling` (../../home/hyprland.nix) deliberately
#     stops Hyprland from upscaling X11 windows — that setting is what keeps
#     Proton games rendering at a real 3840x2160 instead of a 1080p image blown
#     up 2x. Turning it off to make Steam's menus bigger would cost you the
#     resolution of every game. Hyprland has no per-window scale rule either.
#   * STEAM_FORCE_DESKTOPUI_SCALING=2 does nothing. Valve removed it, and the
#     `-forcedesktopscaling` launch flag with it, in the July 2025 client
#     (ValveSoftware/steam-for-linux#12196).
#
# If GDK_SCALE ever stops being enough, the in-client slider is the fallback:
#
#     Steam → Settings → Accessibility → UI Scale
#
# Set it once and Steam stores it in ~/.local/share/Steam/config/config.vdf.
# That file is Steam's own mutable state, rewritten whenever the client exits,
# so it is deliberately NOT managed from here: home-manager would either fight
# the client for it or hand it a read-only symlink and break the setting
# entirely — the same failure that was producing the login popups from
# Caelestia (see ../../home/caelestia.nix).
{pkgs, ...}: {
  # ── ntsync ──────────────────────────────────────────────────────────────
  # The kernel's emulation of the NT synchronisation primitives — the thing
  # Wine used to fake with esync (file descriptors) and fsync (futexes). It is
  # faster than both, and it fixes a class of crash that esync/fsync produce
  # under contention. Arknights: Endfield is one of the titles where that shows
  # up; the community workaround for older kernels, WINEFSYNC=0, trades the
  # crash for a performance loss and is not needed here.
  #
  # Requirements, both already met on this machine:
  #   * CONFIG_NTSYNC, which landed in 6.14. ./boot.nix pins the nixpkgs
  #     default kernel, and that is 6.18 as of 26.05 — comfortably past it.
  #   * Proton that uses it. GE-Proton has had it on by default since 10.10;
  #     Valve's own Proton still wants PROTON_USE_NTSYNC=1, which is set
  #     globally below rather than per game.
  #
  # `modprobe` returns success for a module that is built into the kernel
  # rather than shipped as a .ko, so this line is correct either way.
  #
  # Nothing is needed for permissions: the driver sets /dev/ntsync to 0666
  # itself (the patch that does it was merged with the driver, after the
  # maintainers rejected pushing it onto every distro's udev rules). If
  # `ls -l /dev/ntsync` ever says otherwise, the fix is one udev rule:
  #   services.udev.extraRules = ''KERNEL=="ntsync", MODE="0666"'';
  #
  # To check it is working: launch a game, then
  #   lsof /dev/ntsync        # wine and the game should both be listed
  boot.kernelModules = ["ntsync"];

  programs.steam = {
    enable = true;

    # ── Launch options, set once instead of per game ──────────────────────
    # Steam's per-game "Launch Options" box is the usual place for these, and
    # it is stored in Steam's own mutable config, i.e. nowhere this repo can
    # reach. `extraEnv` is the declarative equivalent: the variables are
    # exported inside Steam's FHS environment, so every game inherits them and
    # the Launch Options box stays empty.
    #
    # Deliberately NOT here:
    #   * gamemode. It is a wrapper, not a variable — `gamemoderun %command%`
    #     stays a per-game launch option. It could be forced globally with
    #     LD_PRELOAD=libgamemodeauto.so.0, but a session-wide LD_PRELOAD inside
    #     the FHS is a good way to break the odd 32-bit title for a small win.
    #   * gamescope. Same reason, and it is a per-game decision anyway.
    package = pkgs.steam.override {
      extraEnv = {
        # MangoHud on for every Vulkan title. The HUD itself is hidden —
        # `no_display` in ../../home/programs/mangohud.nix — because what this
        # is actually for is the 117 fps cap that keeps frame rates inside the
        # G-Sync window. Shift_R+F12 shows the overlay when you want numbers.
        MANGOHUD = "1";

        # Valve's Proton needs to be told; GE-Proton ≥ 10.10 already is.
        # Harmless on a build that does not know the variable, and harmless on
        # a kernel without the driver — Proton falls back to fsync.
        PROTON_USE_NTSYNC = "1";
      };

      # MangoHud's Vulkan layer has to exist INSIDE the FHS sandbox, not just
      # on the host: a game runs under pressure-vessel and only sees what the
      # container was built with. Setting MANGOHUD=1 without this is the usual
      # reason the overlay "does nothing" on NixOS.
      #
      # 64-bit only. A 32-bit-only title will not pick the layer up, and for
      # those the fallback is the per-game launch option `mangohud %command%`.
      extraPkgs = pkgs': with pkgs'; [mangohud];
    };

    # gamescope session — a micro-compositor Steam can run games inside. Useful
    # for games that mishandle a tiling WM, and for forcing a resolution
    # independent of the desktop.
    gamescopeSession.enable = true;

    # Winetricks-through-Proton, for the occasional game that needs a runtime
    # dropped into its prefix.
    protontricks.enable = true;

    # Proton-GE alongside Valve's Proton. ProtonPlus (below) can install more
    # into ~/.steam/root/compatibilitytools.d at runtime — that directory is
    # writable and outside the store, so imperative installs keep working.
    extraCompatPackages = [pkgs.proton-ge-bin];

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
    # Lets gamescope raise its own scheduling priority. Without it you get a
    # warning and slightly worse frame pacing.
    capSysNice = true;
  };

  # gamemoded — applies CPU governor and I/O priority tweaks for the duration of
  # a game. Steam launch option:  gamemoderun %command%
  programs.gamemode = {
    enable = true;
    settings = {
      general.renice = 10;
      # The 7950X3D already runs the performance governor (see ./cpu.nix), so
      # gamemode has little to do on the CPU side — but it also handles the GPU
      # and I/O priority, which still helps.
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    # ProtonPlus — GUI manager for Proton/Wine builds. This is how you install
    # "Proton DW" for Arknights: Endfield; it writes into
    # ~/.steam/root/compatibilitytools.d and Steam picks it up on next restart.
    protonplus

    # mangohud is NOT here. It is installed and configured by home-manager
    # (../../home/programs/mangohud.nix), which is also what writes the config
    # file the frame cap lives in, and it is injected into Steam's FHS by the
    # `extraPkgs` above. Installing it a third time system-wide would only
    # confuse which copy is being read.
    protonup-qt # alternative to ProtonPlus if it ever misbehaves
    winetricks
  ];

  # Games and shader caches are large and open a lot of files at once.
  # The default 1024 soft limit makes some Proton titles fail to launch.
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "524288";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "1048576";
    }
  ];

  # Several anti-cheat and Proton components want a high vm.max_map_count.
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;
}
