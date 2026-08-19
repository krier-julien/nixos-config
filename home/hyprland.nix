# Hyprland — the compositor config. This file is YOURS: Caelestia supplies the
# shell (bar/launcher/lockscreen), not the window manager rules.
#
# ── Lua, not hyprlang ───────────────────────────────────────────────────────
# Hyprland 0.55 deprecated hyprlang, and 0.56 (what nixpkgs-unstable ships now)
# reads `~/.config/hypr/hyprland.lua`. home-manager follows: because
# `home.stateVersion` is 26.05, `configType` defaults to "lua" — it is pinned
# explicitly below so this never silently flips.
#
# Two consequences worth remembering when editing this file:
#
#   * `settings` is no longer a hyprlang tree. Every top-level attribute is
#     rendered as an `hl.<name>(...)` call, so the shape here mirrors the Lua
#     API: `config` → `hl.config{}`, `window_rule` → `hl.window_rule{}`, and a
#     list value means "call it once per element".
#
#   * `extraConfig` is pasted into hyprland.lua VERBATIM. It must be valid
#     **Lua**: comments are `--`, not `#`. (The `#` comments in *this* file are
#     Nix comments — they are stripped at evaluation and never reach the
#     generated file at all.)
#
# The keybinds below reproduce Caelestia's upstream cheat sheet, so muscle
# memory carries over. The shell is driven through Hyprland's `global`
# dispatcher (`caelestia:launcher`, `caelestia:lock`, …) — those names are
# registered by the running shell, so a bind that "does nothing" almost always
# means the shell isn't up, not that the bind is wrong. Check with:
#   systemctl --user status caelestia
{
  lib,
  pkgs,
  ...
}: let
  # ── The session environment, defined ONCE ───────────────────────────────
  # These four are consumed twice below, and that is the whole point.
  #
  # `hl.env` only reaches processes Hyprland itself spawns — the autostart
  # block, and anything a keybind execs. It does NOT reach an app started from
  # Caelestia's launcher, because the shell runs as a systemd user service
  # (../home/caelestia.nix) and its children inherit the *user manager's*
  # environment, which was fixed at session start, before Hyprland ever read
  # this file.
  #
  # That asymmetry is exactly the Steam bug: autostarted Steam scaled, and the
  # same Steam relaunched from the launcher came up half-size, because
  # GDK_SCALE=2 is what switches Steam's client into its 2× UI mode and only
  # the autostart path was handing it over.
  #
  # So the same attrset is also written to ~/.config/environment.d, which the
  # systemd user manager reads at login. Every launch path then agrees.
  sessionEnv = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "24";

    # The other half of the HiDPI XWayland recipe. `force_zero_scaling` below
    # stops Hyprland from upscaling X11 windows — that is what keeps a Proton
    # game rendering at the panel's real 3840x2160 instead of a blurry
    # 1920x1080 blown up 2x. The cost is that XWayland apps are then handed raw
    # pixels and have to scale THEMSELVES, and nothing told them to, which is
    # why everything X11 came up half-size on the 55" TV.
    #
    # GDK_SCALE is the documented fix (wiki.hypr.land → Configuring →
    # XWayland). It is read by GTK's X11 backend, and — separately — by Steam,
    # which has used it since 2018 as the switch for its 2× client UI.
    #
    # Not set here on purpose:
    #   QT_SCALE_FACTOR — Qt reads it on Wayland too, so it WOULD double-scale
    #     Caelestia's shell (Quickshell is Qt).
    #   STEAM_FORCE_DESKTOPUI_SCALING — Valve deleted it in July 2025
    #     (ValveSoftware/steam-for-linux#12196). See ../modules/nixos/
    #     gaming.nix for what replaced it.
    GDK_SCALE = "2";
  };
in {
  # ~/.config/environment.d/10-home-manager.conf. Read by the systemd user
  # manager when it starts, so every user service — and everything those
  # services spawn, Caelestia's launcher included — inherits these.
  systemd.user.sessionVariables = sessionEnv;

  wayland.windowManager.hyprland = {
    enable = true;

    # The system already installs Hyprland via programs.hyprland (which is what
    # sets up uwsm, portals and the session file). Setting these to null tells
    # home-manager to write the config only, instead of installing a second,
    # differently-built Hyprland that would shadow it on PATH.
    package = null;
    portalPackage = null;

    # uwsm owns the session and starts graphical-session.target itself; letting
    # home-manager also manage a hyprland-session target would give you two
    # things racing to own the same target.
    systemd.enable = false;

    # Write hyprland.lua (Hyprland ≥ 0.55). The alternative, "hyprlang", still
    # writes the old hyprland.conf, which current Hyprland only reads as a
    # deprecated fallback.
    configType = "lua";

    settings = {
      # ── Monitors ────────────────────────────────────────────────────────
      # An empty `output` is the catch-all rule. Replace once you know the real
      # names — `hyprctl monitors` prints them. Example for a 1440p240 primary:
      #   monitor = [{output = "DP-1"; mode = "2560x1440@240"; position = "0x0"; scale = "1";}];
      monitor = [
        {
          output = "HDMI-A-1";
          mode = "3840x2160@119.88";
          position = "auto";
          scale = "2";
        }
      ];

      # ── Environment ─────────────────────────────────────────────────────
      # The NVIDIA/toolkit variables live in modules/nixos/nvidia.nix so they
      # apply to the greeter and to non-Hyprland sessions too. Only genuinely
      # compositor-scoped things belong here.
      #
      # `sessionEnv` (top of this file) is rendered into `hl.env` calls, which
      # take two arguments each — hence the `_args` spelling. The same attrset
      # also goes to environment.d, so the launcher agrees with the autostart.
      env = lib.mapAttrsToList (name: value: {_args = [name value];}) sessionEnv;

      # ── Options ─────────────────────────────────────────────────────────
      # Everything here lands in a single hl.config{} call.
      config = {
        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          col = {
            active_border = {
              colors = ["rgba(cba6f7ff)" "rgba(89b4faff)"];
              angle = 45;
            };
            inactive_border = "rgba(45475aaa)";
          };
          layout = "dwindle";
          resize_on_border = true;
          # Tearing is OFF, and that is a considered choice, not an oversight.
          # It buys one thing — a few ms of latency in a game whose frame rate
          # is above the refresh rate — by letting a scanout show two frames at
          # once. That trade only pays in twitch/competitive play.
          #
          # It also fights the G-Sync setup below. Hyprland cannot do both at
          # once in any useful way: with tearing on, a game that runs past the
          # panel's max refresh makes VRR bounce between max and min refresh
          # (hyprwm/Hyprland discussion #13244), which on an OLED is visible as
          # brightness pumping. VRR is the better half of that pair here.
          allow_tearing = false;
        };

        decoration = {
          rounding = 12;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          blur = {
            enabled = true;
            size = 6;
            passes = 3;
            new_optimizations = true;
            xray = true;
          };
          shadow = {
            enabled = true;
            range = 20;
            render_power = 3;
            color = "rgba(00000055)";
          };
        };

        animations.enabled = true;

        input = {
          kb_layout = "us";
          kb_model = "pc105";
          follow_mouse = 1;
          sensitivity = 0; # raw; do acceleration in the game, not the compositor
          accel_profile = "flat";
          numlock_by_default = true;
        };

        cursor = {
          # Leave hardware cursors ON. Turning them off used to be the standard
          # NVIDIA workaround, but on current drivers it just costs you a frame
          # of cursor latency. This is an int, not a bool: 0 = use hw cursors,
          # 1 = never, 2 = auto (disable while tearing).
          no_hardware_cursors = 0;
          inactive_timeout = 5;
        };

        dwindle = {
          preserve_split = true;
          smart_split = false;
        };

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          force_default_wallpaper = 0;
          # G-Sync. 0 = off, 1 = always on, 2 = fullscreen only, 3 = fullscreen
          # only when the window declares game/video content.
          #
          # This was 1 — always on — despite the comment next to it claiming
          # "fullscreen". Always-on VRR is what makes an OLED flicker: panel
          # brightness varies slightly with refresh rate, so a desktop whose
          # refresh tracks whatever is animating (a cursor, a scroll, a video
          # at 24fps) pumps the brightness several times a second. The LG G3 is
          # a WOLED panel and shows this clearly in dark content.
          #
          # 2 confines VRR to a fullscreen window, i.e. to games, which is
          # where the frame pacing actually matters. 3 would be tighter still,
          # but it depends on the client declaring a content type through
          # content-type-v1, and no XWayland/Proton game does — it would leave
          # you with VRR effectively off.
          #
          # Two things to set outside this file, or none of it does anything:
          #   * On the TV: Settings → General → Devices → HDMI Settings →
          #     turn on "HDMI Deep Colour"/4K@120 for the port, then Game
          #     Optimiser → VRR/G-Sync on.
          #   * Cap the in-game frame rate a few fps below the panel maximum.
          #     VRR only helps below max refresh; above it you are back to
          #     v-sync latency or, with tearing, to the bouncing described
          #     above. `hyprctl monitors` prints the mode actually in use.
          vrr = 2;
          focus_on_activate = true;
          # Formerly new_window_takes_over_fullscreen. 2 = un-fullscreen the
          # covering window when a tiled window asks for focus.
          on_focus_under_fullscreen = 2;
        };

        xwayland.force_zero_scaling = true;
      };

      # ── Animations ──────────────────────────────────────────────────────
      # Curves are emitted before animations (home-manager sorts `curve` into
      # its "important prefixes"), which matters: hl.animation refuses a bezier
      # name it has not seen yet.
      curve = [
        {
          _args = [
            "emphasized"
            {
              type = "bezier";
              points = [[0.2 0.0] [0.0 1.0]];
            }
          ];
        }
        {
          _args = [
            "standard"
            {
              type = "bezier";
              points = [[0.2 0.0] [0.0 1.0]];
            }
          ];
        }
      ];

      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 3;
          bezier = "emphasized";
          style = "popin 80%";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 5;
          bezier = "standard";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 3;
          bezier = "standard";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 4;
          bezier = "emphasized";
          style = "slide";
        }
        {
          leaf = "layers";
          enabled = true;
          speed = 3;
          bezier = "standard";
          style = "fade";
        }
      ];

      # ── Window rules ────────────────────────────────────────────────────
      # Matching properties go in `match`; everything else is an effect. Rules
      # are applied top to bottom, last match wins, so keep the broad ones last.
      window_rule = [
        # ── Daily apps → fixed workspaces ─────────────────────────────────
        # These five are launched at login by the autostart block below, but
        # the placement is done HERE rather than there, because a rule keyed on
        # the window class also holds when you start the app by hand later —
        # and, unlike the exec-time rule, it does not care how many times the
        # process forks before it opens a window (Steam forks a lot).
        #
        # `silent` = put the window there without following it, so login does
        # not yo-yo across five workspaces before settling.
        #
        # ⚠ If an app lands on the wrong workspace, its class is wrong here,
        # not the rule. Read the real one off a running window with:
        #     hyprctl clients | grep -E "class|title"
        # The alternations below are deliberate: several of these apps report a
        # different class depending on whether they came up on Wayland or on
        # XWayland, and the reverse-DNS spellings come from the StartupWMClass
        # in their nixpkgs desktop entries.
        {
          match.class = "(?i)^brave-(origin|browser)$";
          workspace = "1 silent";
        }
        {
          match.class = "(?i)^discord$";
          workspace = "2 silent";
        }
        {
          # Deliberately NOT ^steam_app_.*$ — that is a game, and a game should
          # open wherever you launched it from, not get dragged to workspace 3.
          match.class = "^steam$";
          workspace = "3 silent";
        }
        {
          match.class = "^com\\.obsproject\\.Studio$";
          workspace = "4 silent";
        }
        {
          match.class = "(?i)^(pear-desktop|com\\.github\\.th-ch\\.youtube-music)$";
          workspace = "5 silent";
        }

        # ── Anything Steam launches ───────────────────────────────────────
        # Proton gives every window of a title the same class, `steam_app_<id>`
        # — the game AND the publisher launcher that runs before it. So the
        # cosmetic half applies to all of them (a launcher loses nothing by
        # having square corners and no blur behind it) …
        {
          match.class = "^(steam_app_.*)$";
          no_blur = true;
          rounding = 0;
        }

        # … and the fullscreen half is withheld from the launchers, which is
        # the whole point of this pair. Forcing a 900x600 Ubisoft/EA/Rockstar
        # window to fill a 55" panel stretches it into something unreadable.
        #
        # The class cannot separate them, so the title has to, and `negative:`
        # is Hyprland's "match when this regex does NOT". The list is a
        # heuristic and it is meant to be edited: when a launcher slips through
        # and comes up fullscreen, read its real title off the running window
        #
        #     hyprctl clients | grep -E "class|title"
        #
        # and add it. SUPER+F un-fullscreens it in the meantime.
        #
        # ⚠ The FIRST alternative, `^$`, is the one that is easy to leave out
        # and the one that bites. Arknights: Endfield opens two windows under
        # the same class:
        #
        #     class: steam_app_4111544851   title:
        #     class: steam_app_4111544851   title: GRYPHLINK
        #
        # The named one is the launcher you interact with. The nameless one is
        # a bare backing window, and with only the word list here it matched
        # nothing, so the rule fullscreened it — a white sheet across the whole
        # panel with the logo stranded in the corner. An untitled window is
        # never the thing you want blown up to 4K, so empty titles are exempt
        # outright.
        #
        # `gryphlink` covers the named half; `launcher` would have too, in case
        # a future build titles it after the binary (…/GRYPHLINK/Launcher.exe).
        # Note what is NOT here: `endfield`. The game window is titled after
        # the game, so that word would exempt the game from fullscreen as well,
        # which is the opposite of the point.
        {
          match = {
            class = "^(steam_app_.*)$";
            title = "negative:(?i)(^$|.*(launcher|bootstrap|setup|installer|updater|patcher|crash handler|configuration tool|gryphlink|battle\\.net|ubisoft connect|uplay|ea app|ea desktop|rockstar games|social club|paradox|easyanticheat).*)";
          };
          fullscreen = true;
        }

        # Steam's own chrome misbehaves as a tiled window.
        {
          match = {
            class = "^(steam)$";
            title = "^(Friends List)$";
          };
          float = true;
        }
        {
          match = {
            class = "^(steam)$";
            title = "^(Steam Settings)$";
          };
          float = true;
        }

        # OBS projector/preview windows are more useful floating.
        {
          match = {
            class = "^(com.obsproject.Studio)$";
            title = "^(.*Projector.*)$";
          };
          float = true;
        }

        # Picture-in-picture — matches Caelestia's own resizer rule.
        {
          match.title = "^([Pp]icture[- ]in[- ][Pp]icture)$";
          float = true;
          pin = true;
          keep_aspect_ratio = true;
        }

        # Dialogs
        {
          match.class = "^(pwvucontrol|qpwgraph|blueman-manager|nm-connection-editor)$";
          float = true;
        }
        {
          match.title = "^(Open File|Save File|Choose Files)$";
          float = true;
        }

        # Inhibit the idle/lock timer while anything is fullscreen — stops the
        # lock screen appearing mid-game or mid-stream.
        {
          match.class = ".*";
          idle_inhibit = "fullscreen";
        }
      ];

      # `ignore_alpha = 0` is what `ignorezero` used to be: fully transparent
      # pixels are dropped before the layer is blurred.
      layer_rule = [
        {
          match.namespace = "caelestia-.*";
          blur = true;
          ignore_alpha = 0;
        }
      ];

      # ── Workspace assignment ────────────────────────────────────────────
      # There is no `workspace_rule` any more, on purpose. It used to carry two
      # `on_created_empty` entries that launched Pear Desktop and Discord the
      # first time you opened `special:music` / `special:communication`. Both
      # apps are now autostarted onto numbered workspaces (see `window_rule`
      # above and the autostart block below); keeping the old rules as well
      # would spawn a SECOND copy of each the first time those binds were hit.
    };

    # ── Autostart and keybinds ────────────────────────────────────────────
    # Raw Lua, appended to hyprland.lua as-is. Binds live here rather than in
    # `settings` because the Nix spelling of a bind (`_args` plus inline Lua
    # for the dispatcher) is far less readable than the Lua itself.
    extraConfig = ''
      -- ---- Autostart ----
      -- Caelestia's shell is NOT started here — it runs as a systemd user
      -- service (see ./caelestia.nix), which is why it survives a crash.
      -- hl.exec_cmd goes through `sh -c`, so `&&` and friends work.
      hl.on("hyprland.start", function()
        hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
        hl.exec_cmd("${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store")
        hl.exec_cmd("${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store")
        hl.exec_cmd("${pkgs.bluez}/bin/mpris-proxy") -- bluetooth headset media keys → MPRIS

        -- ---- Daily apps, one per workspace ----
        -- 1 Brave Origin | 2 Discord | 3 Steam | 4 OBS | 5 Pear Desktop
        --
        -- The workspace is ALSO pinned by class in `window_rule` above; this
        -- is the belt to that pair of braces. hl.dsp.exec_cmd takes a table of
        -- window-rule effects and applies them to the window the spawned PID
        -- opens, which catches an app whose class regex up there is wrong —
        -- but it is the rule, not this, that survives an app that forks before
        -- opening its window. Neither alone is reliable for all five.
        --
        -- `silent` on both: the windows appear on their workspaces without
        -- dragging focus along, so login settles on workspace 1.
        hl.dispatch(hl.dsp.exec_cmd("brave-origin",  { workspace = "1 silent" }))
        hl.dispatch(hl.dsp.exec_cmd("discord",       { workspace = "2 silent" }))
        hl.dispatch(hl.dsp.exec_cmd("steam",         { workspace = "3 silent" }))
        hl.dispatch(hl.dsp.exec_cmd("obs",           { workspace = "4 silent" }))
        hl.dispatch(hl.dsp.exec_cmd("pear-desktop",  { workspace = "5 silent" }))
      end)

      local mod = "SUPER"

      -- ---- Caelestia shell (global shortcuts registered by the shell) ----
      -- Tap and release Super on its own to open the launcher.
      hl.bind(mod .. " + SUPER_L", hl.dsp.global("caelestia:launcher"), { release = true })
      hl.bind(mod .. " + N", hl.dsp.global("caelestia:sidebar"))
      hl.bind(mod .. " + K", hl.dsp.global("caelestia:showall"))
      hl.bind(mod .. " + L", hl.dsp.global("caelestia:lock"))
      hl.bind("CTRL + ALT + C", hl.dsp.global("caelestia:clearNotifs"))
      hl.bind("CTRL + ALT + Delete", hl.dsp.global("caelestia:session"))

      -- Restart / kill the shell when a QML reload goes wrong.
      hl.bind("CTRL + SUPER + ALT + R", hl.dsp.exec_cmd("qs -c caelestia kill; sleep .1; caelestia shell -d"))
      hl.bind("CTRL + SUPER + SHIFT + R", hl.dsp.exec_cmd("qs -c caelestia kill"))

      -- ---- Apps ----
      hl.bind(mod .. " + T", hl.dsp.exec_cmd("foot"))
      hl.bind(mod .. " + W", hl.dsp.exec_cmd("brave-origin"))
      hl.bind(mod .. " + E", hl.dsp.exec_cmd("thunar"))
      hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd("pwvucontrol"))

      -- ---- Windows ----
      hl.bind(mod .. " + Q", hl.dsp.window.close())
      hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
      hl.bind(mod .. " + P", hl.dsp.window.pin())
      hl.bind(mod .. " + ALT + space", hl.dsp.window.float())
      hl.bind("CTRL + " .. mod .. " + backslash", hl.dsp.window.center())

      hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
      hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
      hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

      hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
      hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
      hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

      hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
      hl.bind(mod .. " + equal", hl.dsp.window.resize({ x =  100, y = 0, relative = true }))

      hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
      hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- ---- Groups ----
      hl.bind(mod .. " + comma", hl.dsp.group.toggle())
      hl.bind(mod .. " + U",     hl.dsp.window.move({ out_of_group = true }))
      hl.bind("ALT + Tab",        hl.dsp.group.next())
      hl.bind("CTRL + ALT + Tab", hl.dsp.group.prev())

      -- ---- Workspaces ----
      -- 1-9 plus 0 for the tenth; ALT moves the focused window there instead.
      for i = 1, 10 do
        local key = i % 10
        hl.bind(mod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
        hl.bind(mod .. " + ALT + " .. key,    hl.dsp.window.move({ workspace = i }))
      end

      hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

      hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special())

      -- M and D used to toggle special workspaces that launched Pear Desktop
      -- and Discord the first time you opened them. Both apps now autostart
      -- onto numbered workspaces, so the binds jump there instead: same
      -- fingers, same app, and no second copy of it.
      -- M = music = Pear Desktop (5), D = Discord (2).
      hl.bind(mod .. " + M", hl.dsp.focus({ workspace = 5 }))
      hl.bind(mod .. " + D", hl.dsp.focus({ workspace = 2 }))

      -- ---- Capture ----
      -- `caelestia record` drives gpu-screen-recorder, which is installed with
      -- its setuid helper by programs.gpu-screen-recorder in the system config.
      hl.bind("Print", hl.dsp.exec_cmd("caelestia screenshot"))
      hl.bind(mod .. " + SHIFT + S",       hl.dsp.global("caelestia:screenshotFreeze"))
      hl.bind(mod .. " + SHIFT + ALT + S", hl.dsp.global("caelestia:screenshot"))
      hl.bind("CTRL + ALT + R",            hl.dsp.exec_cmd("caelestia record"))
      hl.bind(mod .. " + ALT + R",         hl.dsp.exec_cmd("caelestia record -s"))
      hl.bind(mod .. " + SHIFT + C",       hl.dsp.exec_cmd("hyprpicker -a"))

      -- ---- Wallpaper ----
      -- Picks an .mp4/.webm/.mkv from ~/Vidéos/wallpapers and plays it as the
      -- desktop background, or "None" to fall back to the static one. See
      -- ./services/wallpaper-video.nix.
      hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("pkill fuzzel || wallpaper-video"))

      -- ---- Clipboard / emoji ----
      hl.bind(mod .. " + V",      hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
      hl.bind(mod .. " + period", hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"))

      -- ---- Media ----
      -- `locked = true` keeps these working while the lock screen is up.
      hl.bind("CTRL + " .. mod .. " + space", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
      hl.bind("CTRL + " .. mod .. " + equal", hl.dsp.global("caelestia:mediaNext"),   { locked = true })
      hl.bind("CTRL + " .. mod .. " + minus", hl.dsp.global("caelestia:mediaPrev"),   { locked = true })
      hl.bind("XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
      hl.bind("XF86AudioNext", hl.dsp.global("caelestia:mediaNext"),   { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev"),   { locked = true })

      hl.bind(mod .. " + SHIFT + M",  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
      hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
      hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { repeating = true })
    '';
  };
}
