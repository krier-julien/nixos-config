# ── "Brave didn't shut down correctly" ──────────────────────────────────────
# The symptom: reboot without quitting Brave first, and the next launch opens
# with the crash bubble and an empty window instead of yesterday's tabs.
#
# It is not really a Brave bug. Chromium writes `"exit_type": "Normal"` into
# its Preferences file as the last step of a *voluntary* quit; anything that
# ends the process before that step leaves the previous value, `"Crashed"`,
# on disk, and that is what the bubble reads on the next start.
#
# And nothing in this session ever gave it the chance. Brave is spawned by
# `hl.exec_cmd` from ../hyprland.nix, so it is a plain child of the compositor,
# not a unit systemd knows about. At reboot the user session is torn down, the
# compositor goes with it, and Brave is killed outright — no signal it can act
# on, no time to write anything.
#
# This unit is the missing step. It does nothing while it runs; the work is all
# in ExecStop, which fires when `graphical-session.target` stops — i.e. at
# logout and at reboot, while the session is still nominally up.
#
#   After=graphical-session.target  →  systemd stops this BEFORE the target,
#                                      because units stop in reverse start order
#   PartOf=graphical-session.target →  stopping the target stops this at all
#   TimeoutStopSec=30               →  how long Brave gets to finish
#
# ── Why this is only half the fix ──────────────────────────────────────────
# A clean SIGTERM covers the ordinary reboot. It does not cover a power cut, an
# OOM kill, or a GPU hang — and Chromium's SIGTERM handling has been reported
# flaky often enough (issues.chromium.org/40813875) that it is worth having a
# second line. That second line is one switch inside Brave itself:
#
#     Brave → Settings → Get started → On startup → Continue where you left off
#
# With that set, Brave restores the previous session whether or not the last
# exit was clean, so the bubble stops mattering. It is a Brave preference, in
# Brave's own mutable profile, so it is a manual step (see the README table)
# rather than something declared here — the alternative is an enterprise policy
# file in /etc/brave/policies, which locks the setting and puts a "managed by
# your organisation" banner in the browser for the sake of one checkbox.
{
  lib,
  pkgs,
  ...
}: let
  # Chromium forks one process per tab, plus GPU/network/utility children, and
  # they all share the same binary. Only the *browser* process — the one that
  # owns the profile and writes Preferences — has no `--type=` in its command
  # line, so that is the one to signal; killing the children directly is how
  # you produce the crash flag rather than avoid it.
  cleanExit = pkgs.writeShellScript "browser-clean-exit" ''
    export PATH=${lib.makeBinPath [pkgs.procps pkgs.coreutils pkgs.gnugrep]}:$PATH

    browser_pids() {
      for pid in $(pgrep -u "$(id -u)" -f brave 2>/dev/null); do
        exe=$(readlink "/proc/$pid/exe" 2>/dev/null) || continue
        # Guard against matching an unrelated process that merely mentions
        # "brave" somewhere on its command line — an editor with a note open,
        # say. pgrep has no way to express "and the executable is really this".
        # Deliberately a substring rather than a list of exact names: the
        # binary inside the package has been called brave, brave-browser and
        # brave-origin at various points, and a name this loop does not
        # recognise would make it silently do nothing.
        case "''${exe##*/}" in
          *[Bb]rave*) ;;
          *) continue ;;
        esac
        grep -qz -- '--type=' "/proc/$pid/cmdline" 2>/dev/null && continue
        echo "$pid"
      done
    }

    pids=$(browser_pids)
    [ -n "$pids" ] || exit 0

    # shellcheck disable=SC2086
    kill -TERM $pids 2>/dev/null || true

    # Wait for it to actually finish writing. 24s of polling sits inside the
    # unit's 30s TimeoutStopSec, so systemd's own SIGKILL is the backstop and
    # not the thing that ends the loop.
    i=0
    while [ "$i" -lt 120 ]; do
      [ -n "$(browser_pids)" ] || exit 0
      sleep 0.2
      i=$((i + 1))
    done
  '';
in {
  systemd.user.services.browser-clean-exit = {
    Unit = {
      Description = "Give Brave a chance to exit cleanly when the session ends";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      # A oneshot that stays "active" after doing nothing, purely so that it
      # has a stop to hook. RemainAfterExit is what makes that work.
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = cleanExit;
      TimeoutStopSec = 30;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
