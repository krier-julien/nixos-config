{pkgs, ...}: let
  # ── Equibop, with the two Electron flags its own bug tracker asks for ──────
  # Equibop is the Equicord fork of Vesktop, which was itself the replacement
  # for the official Discord client. Stock nixpkgs wraps it with
  # `--ozone-platform-hint=auto`, i.e. "pick a backend yourself", and on
  # Hyprland that is what these two flags exist to correct:
  #
  #   --ozone-platform=wayland
  #       Decide it here instead of letting Electron guess. Equibop#47 reports
  #       this as the fix for the share picker opening TWICE per screen share;
  #       with only the hint, Chromium still brings up the X11 capture path
  #       alongside the portal. It does not cure the picker reappearing when
  #       the stream actually starts — that one is xdph asking once per
  #       screencast session, see the xdph.conf note in ../hyprland.nix.
  #
  #   --disable-gpu-memory-buffer-video-frames
  #       Same issue: on NVIDIA, Chromium's zero-copy video path fails to
  #       allocate YUV_420_BIPLANAR buffers, spams GBM errors and falls back to
  #       something much slower. Turning the zero-copy path off is the
  #       workaround Equibop#47 gives for it.
  #
  # Both are explicitly labelled upstream Electron problems that Equibop
  # cannot fix in-app, hence flags rather than a setting. Drop this whole
  # wrapper and use plain `equibop` if a later Electron makes it unnecessary.
  #
  # Named apart from `equibop` on purpose: the list below opens with
  # `with pkgs;`, and a let binding of the same name would shadow the nixpkgs
  # attribute silently. Spelling them differently makes it obvious which one
  # is installed.
  equibop-wrapped = pkgs.symlinkJoin {
    name = "equibop-wrapped";
    paths = [pkgs.equibop];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/equibop \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--disable-gpu-memory-buffer-video-frames"
    '';
  };
in {
  home.packages = with pkgs; [
    # ── Communications ──────────────────────────────────────────────────
    # The Discord client, third spelling: official → Vesktop → Equibop. It
    # carries Equicord, so Caelestia's generated palette lands on it without
    # patching the app on every update — the CLI writes into Equicord's and
    # Equibop's theme directories by name (../theme.nix).
    #
    # ⚠ Screen-share audio does not work the way the official client's did.
    # That one sent app audio through Electron's own capture ("System Audio",
    # scoped to the shared window). Equibop uses equimic — a fork of Vesktop's
    # venmic — which pulls audio straight off PipeWire. It needs no config
    # (the nixpkgs build links it against pipewire and libpulseaudio for
    # exactly this), but the OBS→Discord path in ../../modules/nixos/audio.nix
    # has NOT been verified against it — see step 4 in ./obs.nix.
    equibop-wrapped

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
