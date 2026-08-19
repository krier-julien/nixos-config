{pkgs, ...}: {
  home.packages = with pkgs; [
    # ── Communications ──────────────────────────────────────────────────
    # Vesktop: the Vencord-flavoured Discord client, replacing the official
    # one. It ships Vencord built in, so themes — including Caelestia's, see
    # ../theme.nix — apply without patching the app on every update, and it
    # screen-shares through the xdg-desktop-portal (see
    # ../../modules/nixos/desktop.nix) rather than needing XWayland.
    #
    # ⚠ Screen-share audio works differently here. The official client sends
    # app audio through Electron's own capture ("System Audio", scoped to the
    # shared window); Vesktop uses venmic, which pulls the audio straight off
    # PipeWire. It is bundled with the nixpkgs package and needs no extra
    # config, but the OBS→Discord path in ../../modules/nixos/audio.nix has
    # NOT been re-verified against it — see step 4 in ./obs.nix.
    vesktop

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
