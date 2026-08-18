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
{pkgs, ...}: let
  # NSA ID of the MAIN account (the one whose activity gets displayed).
  mainAccountNsaId = "6a3756fd9acdec95";

  # Upstream asks any script hitting Nintendo's API through nxapi to identify
  # itself, so they can distinguish app traffic from automation and reach you if
  # something misbehaves. Without it nxapi warns on every start.
  userAgent = "julien-nxapi-presence/1.0 (personal script; +https://gitlab.fancy.org.uk/samuel/nxapi)";
in {
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
