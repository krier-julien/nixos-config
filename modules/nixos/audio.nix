# PipeWire, plus the "discord_feed" null sink that the OBS → Discord path
# monitors into.
#
# The full routing (documented at length in ~/cachyos-hyprland-caelestia.md §11):
#
#   Elgato 4K X audio source
#         │
#         ├─► pw-loopback "elgato-monitor" ──► HD 560S     (you hear the Switch,
#         │        [ user service, see ../../home/services/elgato-monitor.nix ]   always, no OBS needed)
#         │
#         └─► OBS "Audio Input Capture", monitoring ON
#                  │
#                  └─► null sink "discord_feed"  ──► Discord reads it
#                       [ declared below ]            (silent locally)
#
# The two paths terminate in DIFFERENT places. That is the entire reason you do
# not hear the Switch twice. Do not point OBS's monitoring device back at the
# headset, and do not add a second loopback "to be safe" — either one
# reintroduces the double-audio bug this design exists to avoid.
{pkgs, ...}: {
  # PulseAudio's server is replaced by PipeWire's; leaving both enabled is the
  # classic way to get no sound at all.
  services.pulseaudio.enable = false;

  # Lets PipeWire acquire realtime scheduling priority without running as root.
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # 32-bit games via Proton
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    # --- the null sink --------------------------------------------------
    # An "output device that goes nowhere": anything played into it is
    # inaudible, but its .monitor source can be read by other apps. This is the
    # "empty loopback" the whole Discord path hangs off.
    #
    # Declared system-wide rather than in ~/.config/pipewire so it exists before
    # any user logs in — OBS then always finds it in its device list.
    extraConfig.pipewire."90-discord-feed" = {
      "context.objects" = [
        {
          factory = "adapter";
          args = {
            "factory.name" = "support.null-audio-sink";
            "node.name" = "discord_feed";
            "node.description" = "Discord Feed (OBS monitor)";
            "media.class" = "Audio/Sink";
            # linger: keep the sink alive with no client connected. Without it
            # the sink vanishes when nothing holds it and OBS loses its
            # monitoring device between restarts.
            "object.linger" = true;
            "audio.position" = ["FL" "FR"];
          };
        }
      ];
    };

    # The Elgato and the motherboard codec both run at 48 kHz, so PipeWire never
    # has to resample on the capture path. Stating the rate explicitly stops a
    # 44.1 kHz client from dragging the graph off 48 k.
    extraConfig.pipewire."92-default-rate" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [48000 44100 96000];
        # 1024/48000 ≈ 21 ms is a safe desktop default; the Elgato loopback
        # overrides it to 256/48000 (≈5.3 ms) on its own stream only.
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 256;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    pwvucontrol # per-stream volume — the elgato-monitor stream shows up here
    qpwgraph # visual patchbay; indispensable when routing misbehaves
    helvum # lighter alternative to qpwgraph
    pulseaudio # provides `pactl`/`pacmd` clients only — server stays PipeWire
  ];
}
