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
    # production, not beta or latest. Same reasoning as the kernel choice in
    # ./boot.nix: this is the branch nixpkgs actually tests against the default
    # kernel, and a driver that fails to build is a system that fails to build.
    # Your CachyOS install is on 610.57.04, which is newer — if you want that,
    # switch to `.beta` or `.latest` after the first successful boot, when a bad
    # build costs you a reboot into the previous generation instead of an
    # install.
    package = config.boot.kernelPackages.nvidiaPackages.production;

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

    # Electron apps (Discord, Pear Desktop, CurseForge) default to X11 unless
    # told otherwise; "auto" makes them pick Wayland when it is available.
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
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
