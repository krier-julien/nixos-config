# ── MangoHud ────────────────────────────────────────────────────────────────
# Installed for one job that has nothing to do with an overlay: the frame cap.
#
# The panel runs at 119.88 Hz and VRR is confined to fullscreen windows (see
# ../hyprland.nix). G-Sync only does anything BELOW the panel maximum — go past
# it and you are back to either v-sync latency or, with tearing, a refresh rate
# bouncing between max and min. So every game wants a cap a few frames short of
# the maximum, and setting that per game, in each game's own menu, is a chore
# that gets forgotten exactly once per new install.
#
# MangoHud's limiter is the same number for every title, applied from one file.
# `MANGOHUD=1` is exported inside Steam's FHS environment by
# ../../modules/nixos/gaming.nix, so this applies to games without a per-game
# launch option; for anything outside Steam, prefix it with `mangohud`.
#
# Vulkan only, in practice. The layer is a Vulkan implicit layer, which covers
# everything through DXVK/VKD3D and every native Vulkan title. An OpenGL game
# needs the `mangohud` wrapper (it sets the LD_PRELOAD half) to be capped.
{...}: {
  programs.mangohud = {
    enable = true;

    # NOT enableSessionWide. That sets MANGOHUD=1 for the whole user session,
    # which would load the layer into every Vulkan client on the desktop —
    # Caelestia's shell included. Steam is where the games are, and Steam gets
    # the variable from the system config instead.
    enableSessionWide = false;

    settings = {
      # 117, not 119: the cap has to sit clear of the refresh rate, not on it,
      # or frames land right at the edge of the VRR window and the pacing gets
      # worse rather than better. Two to three below the maximum is the usual
      # advice and matches what the panel does.
      fps_limit = 117;

      # "early" sleeps BEFORE presenting rather than after, which is the lower
      # latency of the two methods and the one to want with VRR.
      fps_limit_method = "early";

      # The HUD is off by default — the cap is the point, the numbers are not.
      # Shift_R+F12 toggles it (MangoHud's own default bind), and everything
      # below is what you see when you do.
      no_display = true;

      fps = true;
      frametime = true;
      frame_timing = true;
      gpu_stats = true;
      gpu_temp = true;
      vram = true;
      cpu_stats = true;
      cpu_temp = true;
      ram = true;

      # Readable on a 55" screen from the sofa, and out of the way of most
      # in-game HUDs.
      position = "top-left";
      font_size = 22;
      background_alpha = "0.4";
    };
  };
}
