# OBS Studio — used to capture the Switch 2 off the Elgato 4K X and hand the
# audio to Discord.
{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;

    # ── The NVIDIA explicit-sync crash ─────────────────────────────────────
    # Opening a preview projector or the multiview kills OBS outright on
    # NVIDIA + Wayland, with:
    #
    #   wp_linux_drm_syncobj_surface_v1: error 4: explicit sync is used,
    #   but no acquire point is set
    #
    # OBS hands Qt a wl_surface it has already bound an OpenGL context to;
    # Qt then commits an SHM buffer to it, which is illegal under explicit
    # sync and the compositor disconnects the client.
    # (obsproject/obs-studio#11641, NVIDIA/egl-wayland#142.)
    #
    # __NV_DISABLE_EXPLICIT_SYNC=1 turns the driver's explicit-sync support
    # off, which sidesteps it. It is set on OBS ONLY, deliberately — explicit
    # sync is what removed the flicker and stutter from NVIDIA's Wayland path
    # generally, so making this a session-wide variable would trade a bug you
    # hit on purpose for one you hit constantly.
    #
    # The wrapper below goes around the plain package; home-manager then wraps
    # THAT again with the plugin paths (programs.obs-studio.finalPackage =
    # wrapOBS cfg.package). Wrapping rather than overriding attributes keeps
    # the binary cache: overrideAttrs would rebuild all of OBS from source on
    # every bump.
    package = pkgs.symlinkJoin {
      name = "obs-studio-no-explicit-sync";
      paths = [pkgs.obs-studio];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/obs \
          --set-default __NV_DISABLE_EXPLICIT_SYNC 1
      '';
      # symlinkJoin does not carry these over on its own, and wrapOBS reads
      # both off whatever package it is handed.
      inherit (pkgs.obs-studio) meta;
      passthru = pkgs.obs-studio.passthru or {};
    };

    plugins = with pkgs.obs-studio-plugins; [
      # Capture a SPECIFIC PipeWire node rather than "whatever the default sink
      # is". This is the plugin that makes the Elgato audio source selectable by
      # name, which matters because the default sink is your headset and picking
      # it would create the double-audio loop this whole setup avoids.
      obs-pipewire-audio-capture

      # Global hotkeys work poorly under Wayland — OBS only receives keys while
      # focused. This plugin restores start/stop-recording hotkeys from inside a
      # fullscreen game.
      obs-wayland-hotkeys

      # Remote control / stream deck style automation.
      obs-websocket
    ];
  };

  # ── Manual setup after first launch ────────────────────────────────────────
  # OBS keeps its config in a binary-ish profile that is not worth generating
  # from Nix. These are the settings that make the Discord path work:
  #
  # 1. Settings → Audio → Advanced → Monitoring Device
  #       →  "Discord Feed (OBS monitor)"
  #    THIS IS THE ONE THAT MATTERS. It redirects OBS's monitoring output away
  #    from your headset and into the null sink. Point it at the headset instead
  #    and you will hear the Switch twice.
  #
  # 2. Sources → + → Video Capture Device (V4L2)
  #       Device      Elgato 4K X  (/dev/video0)
  #       Input       0
  #       Resolution  match the Switch's output
  #    Check what the card actually advertises first:
  #       v4l2-ctl -d /dev/video0 --list-formats-ext
  #
  # 3. Sources → + → Audio Input Capture (or "PipeWire Audio Capture (Device)")
  #       Device      alsa_input.usb-Elgato_Elgato_4K_X_...analog-stereo
  #    Then right-click the source → Advanced Audio Properties →
  #       Audio Monitoring:  "Monitor and Output"
  #
  # 4. In Discord: share the OBS window, System Audio ON.
  #    Known Discord bug: browser YouTube audio can leak into the stream too.
  #
  # Verify the graph any time with:  qpwgraph
}
