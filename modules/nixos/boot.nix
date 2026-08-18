{pkgs, ...}: {
  boot.loader = {
    systemd-boot = {
      enable = true;
      # Keep the boot menu from growing without bound — the ESP is 4 GB and each
      # NVIDIA-carrying generation is not small.
      configurationLimit = 20;
      consoleMode = "max";
    };
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  # linux_zen: the closest thing in nixpkgs to what CachyOS gives you — desktop
  # latency tuning and a scheduler tuned for interactivity. `pkgs.linuxPackages_latest`
  # is the alternative if a zen release ever lags behind an NVIDIA driver you need.
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Quiet, flicker-free boot into the greeter.
  boot.plymouth.enable = true;
  boot.kernelParams = ["quiet" "splash" "boot.shell_on_fail"];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # /tmp on tmpfs: fast, and it means a reboot always clears build turds.
  # 64 GB of RAM comfortably absorbs a 25 % cap.
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "25%";
  };
}
