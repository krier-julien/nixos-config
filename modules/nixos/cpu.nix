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
  # exposes a knob for which one the scheduler prefers.
  #
  #   cat /sys/devices/system/cpu/amd_x3d_vcache/mode   -> cache | frequency
  #
  # "cache" is the right default for a machine whose heaviest load is games.
  # If this path doesn't exist on your kernel the service just no-ops.
  systemd.services.amd-x3d-vcache-mode = {
    description = "Prefer the 3D V-Cache CCD for scheduling";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      knob=/sys/devices/system/cpu/amd_x3d_vcache/mode
      if [ -w "$knob" ]; then
        echo cache > "$knob"
        echo "amd_x3d_vcache mode set to: $(cat "$knob")"
      else
        echo "amd_x3d_vcache knob not present on this kernel — nothing to do."
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
