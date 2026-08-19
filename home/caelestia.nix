# The Caelestia shell — bar, launcher, dashboard, notifications, lock screen,
# and the Material You colours that get regenerated from the wallpaper.
#
# Caelestia owns the shell. ./hyprland.nix, which is ours, owns the compositor.
# The community "full dots" ports bundle a Hyprland config too; the most
# complete one is archived and self-described as very experimental, so it is
# not a base to build a daily driver on.
#
# ── Which Caelestia ────────────────────────────────────────────────────────
# Not the official flake: ../flake.nix pulls AdiAmbassador's shell and cli
# forks, which add animated wallpapers to the shell's own picker. See the
# `caelestiaShell` / `caelestiaCli` block below for what that costs us.
#
# ── Why the config files are written by hand ───────────────────────────────
# `programs.caelestia.settings` and `.cli.settings` exist, and are deliberately
# not used. The module renders them through `xdg.configFile`, i.e. as symlinks
# into the read-only store — and the shell rewrites its own config file on
# every start:
#
#   "On every shell start, the config system rewrites the shell.json file it
#    just read. The write comes from the auto-save hook, which treats the
#    property changes delivered after a load as user edits."
#       — caelestia-dots/shell PR #1838 (open, unmerged as of 2026-08)
#
# Writing to an immutable file fails, and the shell toasts "Failed to save
# config" at every login. That is the popup storm after the greeter. cli.json
# has the same bug.
#
# There is a second popup source worth knowing, because it looks identical:
# the shell toasts "Unknown option in config" once per key it does not
# recognise, rather than ignoring it. Three settings below were stale and doing
# exactly that — see the ⚠ notes on `bar.statusIcons`, `general.apps` and the
# palette. After a Caelestia bump, suspect this first:
#   journalctl --user -u caelestia -b
# names the offending keys.
#
# So the settings stay here in Nix as the source of truth, but get *installed*
# as ordinary writable files at activation instead of symlinked. The shell's
# pointless rewrite then succeeds silently, and every rebuild puts the declared
# content back.
#
# The trade: anything changed from inside the shell's control centre is
# overwritten on the next rebuild. Change it here instead. When PR #1838 lands,
# the activation block below can go back to plain `programs.caelestia.settings`.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  # ── Patching the forks' Nix packaging ──────────────────────────────────────
  # AdiAmbassador's forks are built for Arch: their install script `pacman -S`s
  # what the video wallpapers need and gets on with it. The nix/ directories
  # came along from upstream untouched, so on NixOS two dependencies are simply
  # missing, and the feature fails at runtime rather than at build time — which
  # is the annoying way round. Both gaps are patched here rather than by
  # forking again.
  #
  # If video wallpapers build fine but do nothing, these two are where to look:
  #   * a black background and a QML "module QtMultimedia is not installed" in
  #     `journalctl --user -u caelestia` → the shell override
  #   * wallpapers listed but no thumbnails, and no colour change on selection
  #     → the cli override
  caelestiaCli =
    inputs.caelestia-cli.packages.${system}.default.overrideAttrs (old: {
      # utils/wallpaper.py shells out to `ffmpeg` and `ffprobe` to pull a frame
      # for the thumbnail and for the Material You palette. Neither is in the
      # upstream package because upstream has no video code. Same mechanism the
      # package already uses for grim/slurp/fuzzel, so nothing new is invented.
      propagatedBuildInputs =
        (old.propagatedBuildInputs or []) ++ [pkgs.ffmpeg-headless];
    });

  # modules/background/VideoWallpaper.qml is `import QtMultimedia` — MediaPlayer
  # and VideoOutput, no mpv anywhere. Adding qtmultimedia to buildInputs is
  # enough because wrapQtAppsHook (already in nativeBuildInputs) then puts both
  # its QML module and its media backend plugin on the wrapper's search paths.
  # Overriding the `quickshell` argument would be the other way in, but it is
  # more fragile: nix/default.nix already calls `withModules` on it.
  caelestiaShell =
    (inputs.caelestia-shell.packages.${system}.caelestia-shell.override {
      withCli = true;
      caelestia-cli = caelestiaCli;
    })
    .overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [pkgs.qt6.qtmultimedia];
    });

  # ── shell.json ─────────────────────────────────────────────────────────────
  # Everything not listed keeps Caelestia's own default.
  shellSettings = {
    bar = {
      # ⚠ This was `bar.status = { showAudio = ...; showBattery = ...; }` and
      # that whole subtree stopped existing in caelestia-dots/shell 688142e,
      # "refactor!: bar status icons -> entries list" (#1761, 2026-08-04). The
      # shell does not fail on a key it does not know — it raises an "Unknown
      # option in config" toast for each one, at every login, which is the
      # other half of the popup storm.
      #
      # The replacement is an ORDERED list, and loading it replaces the list
      # wholesale rather than merging, so every icon has to be named here even
      # where the value matches the upstream default. Order is bar order.
      statusIcons = [
        {
          id = "lockStatus";
          enabled = true;
        }
        {
          id = "audio";
          enabled = true; # upstream default is false
        }
        {
          id = "microphone";
          enabled = false;
        }
        {
          id = "kbLayout";
          enabled = false;
        }
        {
          id = "network";
          enabled = true;
        }
        {
          id = "bluetooth";
          enabled = true;
        }
        {
          id = "battery";
          enabled = false; # desktop; upstream default is true
        }
      ];

      workspaces = {
        # How many slots the bar draws, NOT how many workspaces exist. The
        # widget pages in blocks of this size:
        #
        #     groupOffset = floor((activeWsId - 1) / shown) * shown
        #
        # so at 5 the bar shows 1–5 while you are on any of them, and flips to
        # 6–10 the moment you hit SUPER+6. Nothing is reserved for workspaces
        # you are not using, and the bar never changes width.
        #
        # This was 10, which pinned ten always-visible slots for five apps.
        # 5 is also upstream's default (plugin/src/Caelestia/Config/
        # barconfig.hpp), so it is really the override that was the mistake —
        # it is spelled out here only because it matches the five autostarted
        # apps in ../hyprland.nix, and should be changed with them.
        shown = 5;
        activeIndicator = true;
        showWindows = true;
      };
    };

    # ── Where the picker looks ─────────────────────────────────────────────
    # Set explicitly, because the default is wrong on this machine and fails
    # silently. Upstream defaults `wallpaperDir` to Qt's PicturesLocation +
    # "/Wallpapers" (plugin/src/Caelestia/Config/userpaths.hpp), and Qt takes
    # PicturesLocation from XDG — which is `~/Images` here, since the locale is
    # fr_LU. So the default resolves to `~/Images/Wallpapers`, capital W, while
    # everything in this repo has always created `~/Images/wallpapers`. On
    # btrfs those are two different directories, and the one the shell reads is
    # the empty one.
    #
    # Naming the path here ends the guessing: no locale, no capitalisation, no
    # difference between what Nix creates and what the shell opens.
    paths.wallpaperDir = "~/Images/wallpapers";

    # No `browser` here. It looks like it belongs next to the others, but the
    # shell has never had one — the apps it knows about are terminal, audio,
    # playback and explorer, and it was another "Unknown option" toast. The
    # browser is chosen by xdg.mimeApps in ./programs/apps.nix, which is what
    # the shell (and everything else) goes through to open a URL anyway.
    general = {
      apps = {
        terminal = ["foot"];
        explorer = ["thunar"];
        audio = ["pwvucontrol"];
      };

      # ── Idle: lock, blank, never sleep ─────────────────────────────────
      # Idle handling belongs to the shell, not to hypridle. Caelestia moved
      # it in-house, so this machine has no hypridle and should not grow one —
      # two idle daemons watching the same seat is how you get a screen that
      # locks twice and blanks at the wrong moment.
      #
      # `timeouts` is a LIST, and the same rule applies as to bar.statusIcons
      # above: loading it replaces the list wholesale rather than merging into
      # the default. That is exactly what is wanted here, because the upstream
      # default ends with a suspend-then-hibernate step and this box has no
      # business sleeping — it is a desktop, and a suspend costs you the
      # loopback, the Rich Presence, and whatever was downloading.
      #
      # Removing that entry is the entire "disable sleep" change. Nothing else
      # in this session suspends on a timer; ../modules/nixos/desktop.nix
      # pins logind's own IdleAction to `ignore` so it stays that way.
      # `systemctl suspend` by hand, and the session menu's entries, still
      # work — this is about the timer, not about the capability.
      idle = {
        # A manual suspend still locks first, so you do not come back to an
        # unlocked desktop.
        lockBeforeSleep = true;

        # Anything playing audio holds the whole idle chain off. Between this
        # and the `idle_inhibit = "fullscreen"` window rule in ../hyprland.nix,
        # a film or a game will not be interrupted.
        inhibitWhenAudio = true;
        inhibitWhenCharging = false; # desktop; there is no battery

        # ONE entry, by choice. Upstream ships three — lock, then `dpms off`,
        # then `suspendThenHibernate` — and the list replaces rather than
        # merges, so what is written here is the entire policy.
        #
        # The dropped `dpms off` step is worth knowing about rather than
        # rediscovering: on a WOLED, an image held on screen for hours is the
        # burn-in case, and the lock screen is exactly that kind of image. The
        # panel's own protections — pixel shift, logo dimming, the compensation
        # cycle it runs on standby — are what is carrying that risk now. If a
        # faint ghost of the lock screen ever shows up on a grey slide, this is
        # the entry to put back:
        #
        #   { timeout = 900; idleAction = "dpms off"; returnAction = "dpms on"; }
        timeouts = [
          # 10 minutes → lock. Change this number, nothing else, to retime it.
          {
            timeout = 600;
            idleAction = "lock";
            inhibitWhenAudio = true;
            respectInhibitors = true;
          }
        ];
      };
    };

    # `appearance.palette.autoMode` used to be set here and is not a config key
    # either — third "Unknown option" toast. Deriving the palette from the
    # wallpaper is a scheme you SELECT, once, at runtime rather than a setting:
    #
    #     caelestia scheme set -n dynamic
    #
    # After that every `caelestia wallpaper` regenerates the colours, and the
    # choice persists in the shell's own state.

    lock.recolourLogo = true;

    services = {
      # 24-hour clock, matching the fr_LU locale.
      useTwelveHourClock = false;
      # Weather needs a location; left off rather than shipping a placeholder
      # that silently reports the wrong city.
      weatherLocation = "";
    };
  };

  # ── cli.json ───────────────────────────────────────────────────────────────
  cliSettings = {
    theme = {
      enableTerm = true;
      enableHypr = true;
      # Compiles the palette with `sass` into the theme directories the CLI
      # knows by name (Vencord, BetterDiscord, Equicord, vesktop, equibop,
      # legcord). The official client reads none of them, so this is a no-op
      # today — left on because it costs nothing and works the moment a mod
      # is installed.
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

  caelestiaDir = "${config.xdg.configHome}/caelestia";
in {
  imports = [inputs.caelestia-shell.homeManagerModules.default];

  programs.caelestia = {
    enable = true;
    package = caelestiaShell;

    # Adds the `caelestia` CLI to PATH: screenshot, record, clipboard, emoji,
    # wallpaper, scheme. The Hyprland keybinds in ./hyprland.nix call it.
    cli = {
      enable = true;
      package = caelestiaCli;
    };

    # Run the shell as a systemd user service rather than an exec-once. It then
    # restarts on crash and you get `journalctl --user -u caelestia` when
    # something goes wrong, which an exec-once gives you neither of.
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };

    # settings / cli.settings deliberately left unset — see the header comment.
    # Leaving them empty is what stops the module from creating the read-only
    # symlinks that the shell then fails to write to.
  };

  # Install the two config files as ordinary, writable files. `linkGeneration`
  # is the home-manager step that creates and removes the store symlinks, so
  # running after it is what lets this replace a symlink left by an earlier
  # generation (which `install` would otherwise try to write *through*, into
  # the store, and fail).
  home.activation.caelestiaWritableConfig =
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      run mkdir -p $VERBOSE_ARG "${caelestiaDir}"

      run rm -f $VERBOSE_ARG "${caelestiaDir}/shell.json"
      run install -m 0644 $VERBOSE_ARG \
        "${pkgs.writeText "caelestia-shell.json" (builtins.toJSON shellSettings)}" \
        "${caelestiaDir}/shell.json"

      run rm -f $VERBOSE_ARG "${caelestiaDir}/cli.json"
      run install -m 0644 $VERBOSE_ARG \
        "${pkgs.writeText "caelestia-cli.json" (builtins.toJSON cliSettings)}" \
        "${caelestiaDir}/cli.json"
    '';

  # ── Where wallpapers go ────────────────────────────────────────────────────
  # Two directories, and the split is what the picker's two categories are:
  #
  #   ~/Images/wallpapers            stills
  #   ~/Images/wallpapers/Animated   .mp4 / .webm / .mkv
  #
  # `Animated` is hardcoded in the fork (services/Wallpapers.qml looks for
  # `Paths.wallsdir + "/Animated"`), capital A included — renaming it here just
  # empties the animated tab. Both are created empty so the picker has
  # somewhere to look before you have put anything in them.
  #
  # Either kind regenerates the whole colour scheme when you pick it; for a
  # video the palette comes from one extracted frame.
  home.file = {
    "Images/wallpapers/.keep".text = "";
    "Images/wallpapers/Animated/.keep".text = "";
  };
}
