# CurseForge desktop app — not in nixpkgs. Upstream ships an AppImage, which
# appimageTools unpacks and re-links against the store instead of the FHS paths
# the bundle assumes.
{
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
  jdk21,
  jdk17,
  jdk8,
}: let
  pname = "curseforge";

  # Read off the AppImage's own desktop entry (X-AppImage-Version).
  version = "1.316.0-37372";

  src = fetchurl {
    # Upstream publishes only a "latest" URL — there is no versioned download.
    # That means this hash goes stale on every CurseForge release, and the build
    # will fail with a hash mismatch rather than silently install something else.
    # When that happens:  ../../scripts/update-curseforge.sh
    url = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage";
    hash = "sha256-ZH4ZkFSoT8bQgcQPkszcux4gds4DHwrD7Vyub+13mgQ=";
  };

  # The bundle's own .desktop is written for AppRun; rewrite it to point at the
  # wrapper, and keep the URL scheme handlers so "Install with CurseForge"
  # buttons on the website work.
  desktopItem = makeDesktopItem {
    name = pname;
    # --no-sandbox belongs here, in the Exec line. appimageTools.wrapType2 has
    # no argument for injecting flags: it builds on buildFHSEnv and sets
    # runScript itself to "appimage-exec.sh -w <contents> --", forwarding "$@".
    # Electron's chrome-sandbox needs a setuid helper that an AppImage unpacked
    # into the Nix store cannot have, so without this the app exits immediately
    # with a SUID sandbox error.
    exec = "${pname} --no-sandbox %U";
    icon = pname;
    desktopName = "CurseForge";
    comment = "The CurseForge Electron App";
    categories = ["Utility" "Game"];
    startupWMClass = "CurseForge";
    mimeTypes = [
      "x-scheme-handler/curseforge"
      "x-scheme-handler/cfauth"
      "x-scheme-handler/curseforge-checkout"
    ];
  };

  contents = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraPkgs = _pkgs: [
      # Modded Minecraft spans Java versions: 8 for 1.12-era packs, 17 for
      # 1.17-1.20, 21 for current. CurseForge will find whichever the pack asks
      # for on PATH inside the FHS environment.
      jdk21
      jdk17
      jdk8
    ];

    extraInstallCommands = ''
      # Replace the bundled desktop entry with the rewritten one.
      install -Dm444 ${desktopItem}/share/applications/${pname}.desktop \
        -t $out/share/applications

      # Icons, so it isn't a grey square in the launcher.
      for size in 16 32 48 64 128 256 512; do
        icon="${contents}/usr/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
        if [ -f "$icon" ]; then
          install -Dm444 "$icon" \
            "$out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
        fi
      done
      if [ -f "${contents}/${pname}.png" ]; then
        install -Dm444 "${contents}/${pname}.png" \
          "$out/share/pixmaps/${pname}.png"
      fi
    '';

    meta = {
      description = "CurseForge desktop app for managing Minecraft mods and modpacks";
      homepage = "https://www.curseforge.com/download/app";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
