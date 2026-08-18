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
