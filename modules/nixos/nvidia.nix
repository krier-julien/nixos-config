# RTX 4090 (AD102) under Wayland/Hyprland.
{
  config,
  pkgs,
  ...
}: {
  # Even on a pure Wayland session this is the switch that installs the driver,
  # builds the kernel module and wires up libglvnd. The option name is a
  # historical artefact — there is no X server here beyond XWayland.
  services.xserver.videoDrivers = ["nvidia"];

  hardware.graphics = {
    enable = true;
    # 32-bit userspace for Steam/Proton. Without this, most Windows games fail
    # to find a GL/Vulkan driver at all.
    enable32Bit = true;
  };

  hardware.nvidia = {
    # `latest`, the 6xx branch — deliberately, and this was `production` (595.x)
    # until the machine was up. The tradeoff hasn't changed, only the stakes:
    # nixpkgs tests `production` against the default kernel, so `latest` is the
    # one that can fail to build against a kernel bump and take the whole system
    # build with it. That was unacceptable on install day and is merely annoying
    # now — a bad build costs a reboot into the previous generation.
    #
    # If a rebuild ever dies compiling the NVIDIA module, put `.production`
    # back, rebuild, and move on; nothing else here depends on the branch.
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    # Ada is fully supported by the open kernel modules, and NVIDIA now treats
    # them as the default for Turing and newer. They are the *kernel* modules
    # only — userspace is still the proprietary blob either way.
    open = true;

    # Mandatory for Wayland. Without KMS you get no display at all under
    # Hyprland, not merely a degraded one.
    modesetting.enable = true;

    # Preserve VRAM across suspend/resume. Costs a little RAM, and is the
    # difference between resuming to a desktop and resuming to a black screen.
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # `nvidia-settings` GUI. Mostly useless on Wayland but harmless and
    # occasionally the fastest way to read a fan curve.
    nvidiaSettings = true;
  };

  # nvidia_drm.fbdev=1 gives you a real framebuffer console on the NVIDIA GPU,
  # which is what makes plymouth and the tty usable rather than a blank screen.
  boot.kernelParams = ["nvidia_drm.fbdev=1"];

  environment.sessionVariables = {
    # VA-API through NVDEC — this is what lets OBS and browsers hardware-decode.
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";

    # GBM via nvidia-drm rather than the mesa path.
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Electron apps (Vesktop, Pear Desktop, CurseForge) default to X11 unless
    # told otherwise; "auto" makes them pick Wayland when it is available.
    # Electron reads this itself, from version 28 on.
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # The nixpkgs half of the same story, and the one that was missing.
    # Chromium- and Electron-based packages in nixpkgs are wrapped like this:
    #
    #   --add-flags "${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform-hint=auto ...}}"
    #
    # i.e. the Wayland flags are only passed when NIXOS_OZONE_WL is set. With
    # it unset, that expansion is empty and the app falls back to XWayland —
    # where `xwayland.force_zero_scaling` (see ../../home/hyprland.nix) hands
    # it raw 4K pixels, so it comes up at half size on the TV.
    #
    # Electron apps were partly saved by the variable above, which Electron
    # honours on its own. Brave is plain Chromium, not Electron, so it read
    # neither and was running on XWayland the whole time. This fixes Brave
    # Origin, and gets the extra flags (WaylandWindowDecorations, the Wayland
    # IME) that ELECTRON_OZONE_PLATFORM_HINT alone does not turn on.
    NIXOS_OZONE_WL = "1";
  };

  # NOTE: do *not* set WLR_NO_HARDWARE_CURSORS. It was the standard NVIDIA
  # workaround for years, but Hyprland dropped wlroots and the variable has done
  # nothing since 0.45. Cursor settings now live in `cursor:no_hardware_cursors`
  # in the Hyprland config, and on current drivers you should not need it.

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia # GPU load/VRAM/temp, live
    vulkan-tools # vulkaninfo, for proving Vulkan works before blaming a game
    libva-utils # vainfo, same for hardware decode
  ];
}
