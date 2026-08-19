# ── Animated wallpapers ─────────────────────────────────────────────────────
# Drop .mp4/.webm/.mkv files into ~/Vidéos/wallpapers, press SUPER+SHIFT+W,
# pick one. It plays as the desktop background and comes back at the next
# login. "None" in the same menu returns you to Caelestia's static wallpaper.
#
# The picker looks in FOUR places, not one, and that is deliberate. There are
# already two folders on this machine with "wallpapers" in the name — the one
# above and ~/Images/wallpapers, which is Caelestia's — and no user should have
# to remember which of them takes video. Both spellings of each are searched,
# because `Wallpapers` capitalised is what Caelestia's own docs use:
#
#     ~/Vidéos/wallpapers   ~/Vidéos/Wallpapers
#     ~/Images/wallpapers   ~/Images/Wallpapers
#
# A name found in more than one wins in that order. Missing folders are
# skipped, not an error.
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

    mkdir -p "$HOME/${videoSubdir}" "${stateDir}"

    # Search order. First match wins when a name appears in more than one.
    set -- \
      "$HOME/Vidéos/wallpapers" \
      "$HOME/Vidéos/Wallpapers" \
      "$HOME/Images/wallpapers" \
      "$HOME/Images/Wallpapers"

    # Only the ones that exist — find bails out on the first missing path.
    dirs=$(
      for d in "$@"; do
        [ -d "$d" ] && printf '%s\n' "$d"
      done
    )

    each_dir() {
      [ -n "$dirs" ] || return 0
      printf '%s\n' "$dirs" | while IFS= read -r d; do
        [ -n "$d" ] && "$@" "$d"
      done
    }

    videos_in() {
      find "$1" -maxdepth 1 -type f \
        \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \
        -o -iname '*.mov' -o -iname '*.gif' \) \
        -printf '%f\n'
    }

    # Menu entry -> real path. First directory that has the name wins, which is
    # the search order above.
    match_in() {
      [ -r "$1/$name" ] && printf '%s\n' "$1/$name"
    }

    none="✕   None — static wallpaper"
    empty="⚠   No videos found — put an .mp4 in ~/Vidéos/wallpapers"

    videos=$(each_dir videos_in | sort -u)

    # An empty list used to render as a menu with one entry and no explanation,
    # which looks exactly like a broken picker. Say so instead.
    if [ -n "$videos" ]; then
      menu=$(printf '%s\n%s\n' "$none" "$videos")
    else
      menu=$(printf '%s\n%s\n' "$none" "$empty")
    fi

    choice=$(printf '%s\n' "$menu" | fuzzel --dmenu --prompt "Wallpaper  ") || exit 0
    [ -n "$choice" ] || exit 0

    if [ "$choice" = "$empty" ]; then
      notify-send "Wallpaper" "Looked in: $dirs"
      exit 0
    fi

    if [ "$choice" = "$none" ]; then
      : > "${stateFile}"
      systemctl --user stop wallpaper-video.service
      exit 0
    fi

    name=$choice
    file=$(each_dir match_in | head -n 1)
    [ -n "$file" ] && [ -r "$file" ] || {
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
