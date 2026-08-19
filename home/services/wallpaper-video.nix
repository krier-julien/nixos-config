# ── Animated wallpapers ─────────────────────────────────────────────────────
# Drop .mp4/.webm/.mkv files into ~/Vidéos/wallpapers, press SUPER+SHIFT+W,
# pick one. It plays as the desktop background and comes back at the next
# login. "None" in the same menu returns you to Caelestia's static wallpaper.
#
# ── How it sits next to Caelestia ──────────────────────────────────────────
# Caelestia draws the still wallpaper itself, on the layer-shell `background`
# layer. mpvpaper is put on `bottom` — one layer up, still underneath every
# window — rather than fighting it for the same one. Two consequences, both
# wanted:
#
#   * With no video selected you see Caelestia's wallpaper as before. Nothing
#     about this file changes the default desktop; it is strictly additive.
#   * The shell's own config is untouched. Disabling its background would mean
#     adding a key to shell.json, and an unrecognised key there is a login
#     toast per key (see ../caelestia.nix) — not a trade worth making to avoid
#     drawing one static image nobody can see.
#
# The colour scheme still follows the video: picking one pulls a frame out with
# ffmpeg and hands it to `caelestia wallpaper -f`, so Material You regenerates
# from what is actually on screen. That also keeps the hidden static wallpaper
# matching the video, which is what you see for the instant before mpvpaper
# has its first frame up.
#
# ── Cost ───────────────────────────────────────────────────────────────────
# A looping 4K video is a permanent GPU and power draw — this is a 4090 on a
# desktop, so it does not matter here, but it is the reason this is opt-in per
# wallpaper rather than something the shell does by default. `-p` (auto-pause)
# is deliberately NOT passed: it pauses playback whenever a window is focused,
# which on a tiling WM means "always", and you would never see it move.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Relative to $HOME, and spelled once. The XDG user dirs are French on this
  # machine (fr_LU — see ../common.nix), and `xdg.userDirs.videos` is the
  # string "$HOME/Vidéos", which expands in a shell script but NOT in a
  # `home.file` attribute name. Keeping the relative path here sidesteps that
  # asymmetry entirely.
  videoSubdir = "Vidéos/wallpapers";

  stateDir = "${config.xdg.stateHome}/wallpaper-video";
  stateFile = "${stateDir}/current";
  frameFile = "${stateDir}/frame.png";

  runtimePath = lib.makeBinPath [
    pkgs.mpvpaper
    pkgs.ffmpeg-headless # one frame out of a video; no GUI, no encoders needed
    pkgs.fuzzel
    pkgs.libnotify
    pkgs.coreutils
    pkgs.findutils
    pkgs.systemd # systemctl --user
  ];

  # What the unit runs. Split out from the picker because the two have
  # different jobs: this one is the long-lived process systemd supervises, and
  # it has to be startable on its own at login with no menu in sight.
  runner = pkgs.writeShellScriptBin "wallpaper-video-run" ''
    export PATH=${runtimePath}:$PATH

    # Exiting 0 rather than failing is the point: "no video chosen" is the
    # normal state, not an error, and Restart=on-failure must not fight it.
    [ -s "${stateFile}" ] || {
      echo "no video wallpaper selected"
      exit 0
    }

    file=$(cat "${stateFile}")
    [ -r "$file" ] || {
      echo "selected wallpaper is gone: $file"
      exit 0
    }

    # `*` = every output. `bottom` = above Caelestia's wallpaper, below every
    # window. No --auto-pause, for the reason in the header comment.
    exec mpvpaper -l bottom \
      -o "--loop-file=inf --no-audio --panscan=1.0 --hwdec=auto" \
      '*' "$file"
  '';

  picker = pkgs.writeShellScriptBin "wallpaper-video" ''
    export PATH=${runtimePath}:$PATH

    dir="$HOME/${videoSubdir}"
    mkdir -p "$dir" "${stateDir}"

    none="✕   None — static wallpaper"

    menu=$(
      printf '%s\n' "$none"
      find "$dir" -maxdepth 1 -type f \
        \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \
        -o -iname '*.mov' -o -iname '*.gif' \) \
        -printf '%f\n' | sort
    )

    choice=$(printf '%s\n' "$menu" | fuzzel --dmenu --prompt "Wallpaper  ") || exit 0
    [ -n "$choice" ] || exit 0

    if [ "$choice" = "$none" ]; then
      : > "${stateFile}"
      systemctl --user stop wallpaper-video.service
      exit 0
    fi

    file="$dir/$choice"
    [ -r "$file" ] || {
      notify-send "Wallpaper" "Cannot read $choice"
      exit 1
    }

    printf '%s\n' "$file" > "${stateFile}"
    systemctl --user restart wallpaper-video.service

    # Keep the palette in step with what is on screen. Seek a second in first —
    # plenty of videos open on a black frame, and a black frame makes a grey
    # scheme. Fall back to frame zero for anything shorter than that.
    if ffmpeg -y -loglevel error -ss 1 -i "$file" -frames:v 1 "${frameFile}" \
      || ffmpeg -y -loglevel error -i "$file" -frames:v 1 "${frameFile}"; then
      if command -v caelestia > /dev/null; then
        caelestia wallpaper -f "${frameFile}" || true
      fi
    fi
  '';
in {
  home.packages = [picker runner];

  # The folder the picker reads, created empty so it exists before you have
  # anything to put in it.
  home.file."${videoSubdir}/.keep".text = "";

  systemd.user.services.wallpaper-video = {
    Unit = {
      Description = "Video wallpaper (mpvpaper)";
      # Both are needed and they do different things: After orders it behind
      # the compositor so WAYLAND_DISPLAY exists, PartOf tears it down with the
      # session instead of leaving mpvpaper running against a dead socket.
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${runner}/bin/wallpaper-video-run";
      # Only on failure. A clean exit means "nothing selected", which is a
      # state to stay in, not one to retry.
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
