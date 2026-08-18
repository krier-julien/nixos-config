# nxapi — publishes what you're playing on the Switch as Discord Rich Presence.
#
# How it works: Nintendo's API will not report your OWN presence to your own
# session in a pollable way. The workaround is to authenticate nxapi as a
# SECONDARY Nintendo account that is friends with your main one, and have it
# watch the main account. That is what --friend-nsaid is doing.
#
# Setup, once, after the first boot:
#   nxapi nso auth            # log in as the SECONDARY account
#   nxapi nso friends         # find the MAIN account's NSA ID
# Tokens land in ~/.local/share/nxapi-nodejs/persist/ — treat that directory
# like a password file.
{
  pkgs,
  lib,
  ...
}: let
  # ─────────────────────────────────────────────────────────────────────────
  # ⚠ FLIP THIS TO true — it is the ONLY thing you need to change.
  #
  # nxapi's npmDepsHash in ../../pkgs/nxapi/default.nix is still lib.fakeHash.
  # Nix cannot know a dependency-set hash until it has fetched the set once, so
  # referencing the package at all makes the build fail with a hash mismatch.
  # On install day that would take down the whole system build for the sake of
  # a Discord Rich Presence — so it is off by default.
  #
  # After the first successful boot:
  #     cd ~/nixos-config
  #     ./scripts/update-hashes.sh     # discovers and writes the real hash
  #     sed -i 's/enabled = false/enabled = true/' home/services/nxapi.nix
  #     sudo nixos-rebuild switch --flake .#julien-desktop
  #
  # Then authenticate: see docs/INSTALL.md §7.2.
  # ─────────────────────────────────────────────────────────────────────────
  enabled = false;

  # NSA ID of the MAIN account (the one whose activity gets displayed).
  mainAccountNsaId = "6a3756fd9acdec95";

  # Upstream asks any script hitting Nintendo's API through nxapi to identify
  # itself, so they can distinguish app traffic from automation and reach you if
  # something misbehaves. Without it nxapi warns on every start.
  userAgent = "julien-nxapi-presence/1.0 (personal script; +https://gitlab.fancy.org.uk/samuel/nxapi)";
in
  lib.mkIf enabled {
    # The package lives here rather than in ../programs/apps.nix so that the
    # single `enabled` switch above governs both the binary and the service —
    # there is no way to end up with one without the other.
    home.packages = [pkgs.nxapi];

    systemd.user.services.nxapi = {
      Unit = {
        Description = "nxapi Discord Rich Presence";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";

        # ⚠ The whole KEY=value is wrapped in double quotes, not just the value.
        # systemd splits Environment= on whitespace, so an unquoted value with
        # spaces is silently truncated to its first word and the rest is dropped
        # with "Invalid environment assignment, ignoring:" in the journal.
        # Verify after a rebuild:
        #   systemctl --user show nxapi.service -p Environment
        Environment = [''"NXAPI_USER_AGENT=${userAgent}"''];

        ExecStart = "${pkgs.nxapi}/bin/nxapi nso presence --friend-nsaid ${mainAccountNsaId}";

        # nxapi exits if Discord isn't running yet at login. Retry rather than
        # giving up — 30 s is long enough for Discord to finish starting.
        Restart = "on-failure";
        RestartSec = 30;
      };

      Install = {
        # graphical-session.target ONLY — not default.target as well. On the old
        # machine the unit was linked into both, which works but is contradictory:
        # PartOf=graphical-session.target while default.target starts it whether
        # or not a graphical session exists.
        #
        # This target is only reached properly because the session runs under
        # uwsm (programs.hyprland.withUWSM in modules/nixos/desktop.nix). Without
        # uwsm, Hyprland never activates it and this service never starts.
        WantedBy = ["graphical-session.target"];
      };
    };
  }
