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

  # The nixpkgs DEFAULT kernel, deliberately.
  #
  # linux_zen is the closest thing in nixpkgs to what CachyOS gave you, and it
  # is tempting. But the NVIDIA kernel module has to compile against whatever
  # kernel you pick, and nixpkgs only guarantees that pairing for the default
  # kernel. A zen release that has moved ahead of the driver takes the entire
  # system build down — which on install day means no system at all, with no
  # previous generation to boot back into.
  #
  # Switch AFTER the first successful boot, when a bad build just means picking
  # the older generation in the boot menu:
  #
  #   boot.kernelPackages = pkgs.linuxPackages_zen;     # or _latest, or _xanmod
  #
  # On a 7950X3D driving a 4090 the practical difference is small; amd_pstate
  # and the V-Cache scheduling in ./cpu.nix are where the real gains are, and
  # those are in the mainline kernel.
  boot.kernelPackages = pkgs.linuxPackages;

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
