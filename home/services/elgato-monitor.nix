# Path 1 of the Elgato audio design: an always-on loopback from the capture
# card's audio to the headset, so the Switch 2 is audible whenever the PC is on
# — with OBS closed, with OBS open, it makes no difference.
#
# Path 2 (OBS monitoring → the "discord_feed" null sink) is declared in
# ../../modules/nixos/audio.nix. The two paths terminate in DIFFERENT places;
# that is what stops you hearing the Switch twice.
{pkgs, ...}: let
  # ── Node names ─────────────────────────────────────────────────────────────
  # ⚠ VERIFY THESE ON THE NEW INSTALL before trusting them. The Elgato's serial
  # (A7SNB542249G1I) is baked into its node name, and the motherboard codec's
  # name depends on how ALSA UCM enumerates it.
  #
  #   pactl list short sources | grep -i elgato
  #   pactl list short sinks
  #
  elgatoSource = "alsa_input.usb-Elgato_Elgato_4K_X_A7SNB542249G1I-02.analog-stereo";

  # The HD 560S, plugged into the motherboard's REAR analog jack.
  #
  # Ignore the name. The board exposes its analog codec through a USB audio
  # controller (MSI 0db0:d6e7), so PipeWire calls the whole thing "Generic USB
  # Audio" and ALSA UCM splits it into three sinks:
  #
  #   HiFi__Speaker__sink     "USB Audio Speakers"          ← rear line-out. THIS ONE.
  #   HiFi__Headphones__sink  "USB Audio Front Headphones"  ← front panel, unused
  #   HiFi__SPDIF__sink                                     ← optical, unused
  #
  # The Speakers/Headphones labels come from the jack position, not from what is
  # plugged into it. Picking "Headphones" gets you silence.
  headsetSink = "alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink";

  # 256/48000 ≈ 5.3 ms of buffer: low enough to stay in sync with the picture,
  # high enough not to crackle. The 4K X outputs s16le stereo 48 kHz, which
  # matches PipeWire's clock, so nothing resamples on this path.
  latency = "256/48000";
in {
  systemd.user.services.elgato-monitor = {
    Unit = {
      Description = "Elgato 4K X audio passthrough to headphones";
      After = ["pipewire.service" "wireplumber.service"];
      # PartOf: restarting PipeWire restarts the loopback with it. Without this
      # the loopback survives as an orphan pointing at nodes that no longer
      # exist, and you get silence with a "running" service.
      PartOf = ["pipewire.service"];
    };

    Service = {
      Type = "simple";
      # Deliberately one long line. systemd does accept backslash continuations
      # in unit files, but home-manager writes this value verbatim and a stray
      # indent on a continuation line is a silent parse failure — you get a
      # "running" service that loops nothing.
      ExecStart = "${pkgs.pipewire}/bin/pw-loopback --capture-props=\"target.object=${elgatoSource} node.latency=${latency}\" --playback-props=\"target.object=${headsetSink} node.name=elgato-monitor\"";
      # Covers the Elgato being unplugged and replugged: pw-loopback exits and
      # systemd brings it straight back.
      Restart = "always";
      RestartSec = 2;
    };

    Install = {
      # Tied to PipeWire's lifecycle rather than to login, so it comes up
      # whenever PipeWire does.
      WantedBy = ["pipewire.service"];
    };
  };

  # ── The one way to break this ──────────────────────────────────────────────
  # Never run `pw-loopback` by hand while this service is up. Two loopbacks into
  # one sink IS the "hearing it twice" bug, at double volume.
  #
  #   pgrep -a -f pw-loopback        # want exactly one
  #   cat /proc/<pid>/cgroup         # should say elgato-monitor.service
  #
  # Volume for this stream is independent — it shows up in pwvucontrol under
  # Playback as "elgato-monitor", so you can duck the Switch against PC audio
  # without touching the master.
}
