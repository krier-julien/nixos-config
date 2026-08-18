# Fan and pump control — NZXT Kraken 2023 Elite + Lian Li UNI FAN SL V2 hub.
#
# There is no NZXT CAM and no L-Connect on Linux. liquidctl talks to both devices
# directly over USB HID and is the whole solution: no daemon, no tray app.
# Type=oneshot is correct — liquidctl writes duty cycles into the devices' own
# firmware and exits. Nothing needs to stay resident.
{
  pkgs,
  lib,
  ...
}: let
  lq = "${pkgs.liquidctl}/bin/liquidctl";

  # ── Duty cycles ────────────────────────────────────────────────────────────
  # Change these, rebuild, done. Tune live first with:
  #   sudo liquidctl --match "uni sl" set fan2 speed 70
  pumpDuty = 75;
  fanDuties = {
    fan1 = 40;
    fan2 = 60;
    fan3 = 40;
    fan4 = 45;
  };

  # ── Why --match and not -d 0 / -d 1 ────────────────────────────────────────
  # -d N is a position in liquidctl's enumeration order, which depends on how
  # USB devices come up. A different kernel, a different port, or a device slow
  # to enumerate and -d 0 is no longer the Kraken — at which point you are
  # sending `set pump speed` to a fan hub. --match takes a case-insensitive
  # substring of the device description instead, so it survives re-enumeration.
  #
  # The Kraken driver is flagged experimental by liquidctl, which is why every
  # Kraken command needs --unsafe=EXPERIMENTAL and why `liquidctl list` labels it
  # "(broken)". That is a driver-maturity tag, not a fault in your cooler.
  kraken = "${lq} --unsafe=EXPERIMENTAL --match kraken";
  # Plain double-quoted string with escaped inner quotes. NOT a ''…'' string:
  # there, a leading ''${ is the escape sequence for a literal "${", which would
  # silently ship the text "${lq}" to systemd instead of the store path.
  fans = "${lq} --match \"uni sl\"";
in {
  environment.systemPackages = [pkgs.liquidctl];

  systemd.services.liquidctl = {
    description = "liquidctl hardware initialisation and fan control";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        [
          "${kraken} initialize"
          "${fans} initialize"
          "${kraken} set pump speed ${toString pumpDuty}"
        ]
        ++ lib.mapAttrsToList (port: duty: "${fans} set ${port} speed ${toString duty}") fanDuties;
    };
  };

  # Duty cycles live in device state, which is lost when the devices drop power
  # on suspend-to-RAM. A Type=oneshot boot service will not re-run by itself on
  # resume, so re-trigger it explicitly.
  #
  # --no-block matters: without it this unit waits for liquidctl.service to
  # finish while systemd is still unwinding the sleep transition, which can stall
  # resume. Fire and forget instead.
  systemd.services.liquidctl-resume = {
    description = "Re-apply liquidctl settings after resume";
    after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --no-block restart liquidctl.service";
    };
  };

  # ── The failure mode this config exists to prevent ─────────────────────────
  # On the old machine this unit sat present-but-*disabled* for months, so the
  # duties above were never applied at boot and the hardware ran on firmware
  # defaults. Declaring `wantedBy` in Nix makes "installed" and "enabled" the
  # same act — there is no longer a state where the file exists but is inert.
  # Confirm after the first boot anyway:
  #   systemctl is-enabled liquidctl && systemctl status liquidctl
  #   sudo liquidctl --unsafe=EXPERIMENTAL --match kraken status
}
