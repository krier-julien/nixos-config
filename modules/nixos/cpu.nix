# Ryzen 9 7950X3D — 8 cores with 3D V-Cache + 8 without.
{pkgs, ...}: {
  # amd_pstate in "active" mode hands frequency selection to the CPU's own
  # governor via EPP. On Zen 4 this is both faster to react and more efficient
  # than acpi-cpufreq. Recent kernels default to it, but say it explicitly so a
  # kernel change can't silently move you back to the old driver.
  boot.kernelParams = ["amd_pstate=active"];

  # With amd_pstate=active the governor is an EPP hint, not a hard clock lock.
  # "performance" here means "bias toward clocks over power" — appropriate for a
  # desktop that is plugged into a wall and drives a 4090.
  powerManagement.cpuFreqGovernor = "performance";

  # The 7950X3D's two CCDs are not interchangeable: one has the extra cache
  # (better for games), one clocks higher (better for compiles). Linux 6.13+
  # exposes a knob for which one the scheduler prefers, and "cache" is the right
  # default for a machine whose heaviest load is games.
  #
  # The knob is NOT under /sys/devices/system/cpu — that was this file's first
  # guess and it was wrong, which cost an evening. The driver
  # (drivers/platform/x86/amd/x3d_vcache.c, module amd_3d_vcache) is a platform
  # driver that binds to ACPI device AMDI0101 and hangs its attribute off that
  # device via .dev_groups, so the real path is:
  #
  #   cat /sys/bus/platform/drivers/amd_x3d_vcache/AMDI0101:00/amd_x3d_mode
  #       -> frequency | cache
  #
  # Checking the wrong path is indistinguishable from missing hardware support:
  # the old service logged "knob not present" at every boot on a machine where
  # the driver was loaded and bound the whole time.
  #
  # The mode is set at module load, not afterwards. The driver takes an
  # `x3d_mode` parameter and defaults it to "frequency", so setting it here
  # closes the window where the machine runs on the wrong CCD preference between
  # boot and a late oneshot service. The driver also re-applies it on resume by
  # itself, so no suspend hook is needed.
  boot.extraModprobeConfig = ''
    options amd_3d_vcache x3d_mode=cache
  '';

  # The service no longer sets the mode — it verifies it, loudly. This is a
  # 7950X3D; if the knob is missing, the driver did not bind and the modprobe
  # option above silently did nothing, which is a real finding rather than a
  # shrug. `journalctl -u amd-x3d-vcache-mode` is where you look.
  systemd.services.amd-x3d-vcache-mode = {
    description = "Verify the 3D V-Cache CCD scheduling preference";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      found=
      for knob in /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode; do
        [ -e "$knob" ] || continue
        found=1
        mode=$(cat "$knob")
        if [ "$mode" != cache ]; then
          echo "amd_x3d_mode is '$mode', expected 'cache' — correcting."
          echo cache > "$knob"
          mode=$(cat "$knob")
        fi
        echo "amd_x3d_mode = $mode ($knob)"
      done
      if [ -z "$found" ]; then
        echo "WARNING: no amd_x3d_mode knob. The amd_3d_vcache driver did not"
        echo "bind to ACPI device AMDI0101, so the 3D V-Cache CCD preference is"
        echo "NOT being applied. Check: lsmod | grep vcache;"
        echo "ls /sys/bus/acpi/devices/ | grep AMDI0101"
      fi
    '';
  };

  environment.systemPackages = with pkgs; [
    lm_sensors # sensors — CCD temps
    btop # has an AMD-aware GPU/CPU view
  ];

  # NOT enabling hardware.cpu.amd.ryzen-smu: it builds an out-of-tree kernel
  # module, which is exactly the kind of thing that fails to compile against a
  # new kernel and takes the whole system build down with it. All it buys is
  # per-core SMU telemetry. Turn it on later, once you have generations to roll
  # back to.
}
