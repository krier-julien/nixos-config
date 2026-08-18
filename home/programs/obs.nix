# OBS Studio — used to capture the Switch 2 off the Elgato 4K X and hand the
# audio to Discord.
{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;

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
