{pkgs, ...}: {
  home.packages = with pkgs; [
    # ── Communications ──────────────────────────────────────────────────
    # The OFFICIAL client, deliberately. It is the one proven on the old
    # machine to send app audio on Linux screen share (labelled "System
    # Audio", scoped to the shared window) — which is exactly what the
    # OBS→Discord path depends on. Vesktop/Equibop use a different mechanism
    # (venmic) that would need re-verifying against this setup.
    discord

    # ── Media ───────────────────────────────────────────────────────────
    plezy # Plex/Jellyfin client, Discord Rich Presence built in
    pear-desktop # YouTube Music desktop (upstream renamed from youtube-music)

    # ── Gaming ──────────────────────────────────────────────────────────
    # Steam, ProtonPlus, gamemode and gamescope are system-level — see
    # ../../modules/nixos/gaming.nix (Steam needs system-wide 32-bit graphics
    # and firewall rules, so it cannot live here).
    curseforge # custom package, ../../pkgs/curseforge

    # ── Switch presence ─────────────────────────────────────────────────
    # nxapi is NOT listed here. It is installed by ../services/nxapi.nix,
    # behind the single `enabled` boolean at the top of that file, so the
    # binary and its service can never get out of step. It is off until you
    # have run ./scripts/update-hashes.sh — see the comment there.

    # ── Browser and desktop basics ──────────────────────────────────────
    # Brave Origin is the default (see xdg.mimeApps below): the stripped-down
    # Brave build, with Leo/Rewards/Wallet/VPN/News/Talk/Tor removed rather
    # than merely switched off. Paid elsewhere, free on Linux. Firefox stays
    # installed as a second engine — Brave is Chromium, so when a site breaks
    # in one it is worth trying the other.
    brave-origin
    firefox
    micro
    fastfetch
    file-roller
    loupe # image viewer
    mpv

    # ── CLI ─────────────────────────────────────────────────────────────
    eza
    ripgrep
    fd
    bat
    jq
    dust
    unzip
    p7zip
    wget
    curl
  ];

  # Default applications, so "Open with" and xdg-open behave.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-origin.desktop";
      "x-scheme-handler/http" = "brave-origin.desktop";
      "x-scheme-handler/https" = "brave-origin.desktop";
      "x-scheme-handler/curseforge" = "curseforge.desktop";
      "x-scheme-handler/cfauth" = "curseforge.desktop";
      "inode/directory" = "thunar.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
    };
  };
}
