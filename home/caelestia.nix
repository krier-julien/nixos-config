# The Caelestia shell — bar, launcher, dashboard, notifications, lock screen,
# and the Material You colour generation that recolours everything from the
# wallpaper.
#
# This uses the OFFICIAL flake (github:caelestia-dots/shell) via its own
# home-manager module. Deliberately NOT one of the community "full dots" ports:
# those bundle a Hyprland config too, and the one that ports it most completely
# is archived and self-described as very experimental. Here Caelestia owns the
# shell, and ./hyprland.nix — which is yours, in this repo — owns the compositor.
#
# ── Why the config files are written by hand ────────────────────────────────
# `programs.caelestia.settings` and `.cli.settings` are NOT used below, even
# though they exist. The module renders them through `xdg.configFile`, i.e. as
# a symlink into the read-only nix store — and the shell rewrites its own
# config file on every start:
#
#   "On every shell start, the config system rewrites the shell.json file it
#    just read. The write comes from the auto-save hook, which treats the
#    property changes delivered after a load as user edits."
#       — caelestia-dots/shell PR #1838 (open, unmerged as of 2026-08)
#
# On an immutable file that write fails, and the shell raises a "Failed to save
# config" toast at every login. THAT is the popup storm after entering your
# password at the greeter. Same class of bug for cli.json.
#
# It has a twin worth knowing about, because it produces near-identical popups
# from the same place: the shell also toasts "Unknown option in config" for
# every key it does not recognise, one per key, rather than ignoring it. Three
# of the settings below were stale and were doing exactly that — see the ⚠
# notes on `bar.statusIcons`, `general.apps` and the palette. If new popups
# show up after a Caelestia bump, that is the first thing to suspect, and
#   journalctl --user -u caelestia -b
# names the offending keys.
#
# So: the settings still live here, in Nix, as the single source of truth — but
# they are *installed* as ordinary writable files at activation instead of
# symlinked. The shell's pointless rewrite then succeeds silently, and every
# `nixos-rebuild switch` puts the declared content back.
#
# Consequence worth knowing: anything you change from inside the shell's own
# control centre is overwritten on the next rebuild. Change it here instead.
# When PR #1838 lands upstream this whole activation block can go back to being
# plain `programs.caelestia.settings`.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
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
        shown = 10;
        activeIndicator = true;
        showWindows = true;
      };
    };

    # No `browser` here. It looks like it belongs next to the others, but the
    # shell has never had one — the apps it knows about are terminal, audio,
    # playback and explorer, and it was another "Unknown option" toast. The
    # browser is chosen by xdg.mimeApps in ./programs/apps.nix, which is what
    # the shell (and everything else) goes through to open a URL anyway.
    general.apps = {
      terminal = ["foot"];
      explorer = ["thunar"];
      audio = ["pwvucontrol"];
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

  # Wallpapers. `caelestia wallpaper` reads from here and regenerates the whole
  # colour scheme from whichever one you pick.
  home.file."Images/wallpapers/.keep".text = "";
}
