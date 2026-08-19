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
  programs.steam = {
    enable = true;

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

    mangohud # frame/latency overlay:  mangohud %command%
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
