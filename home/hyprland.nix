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
{pkgs, ...}: {
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
          mode = "3840x2160@199.88";
          position = "auto";
          scale = "2";
        }
      ];

      # ── Environment ─────────────────────────────────────────────────────
      # The NVIDIA/toolkit variables live in modules/nixos/nvidia.nix so they
      # apply to the greeter and to non-Hyprland sessions too. Only genuinely
      # compositor-scoped things belong here. `hl.env` takes two arguments, so
      # each entry is spelled with `_args`.
      env = [
        {_args = ["XCURSOR_THEME" "Bibata-Modern-Classic"];}
        {_args = ["XCURSOR_SIZE" "24"];}
        {_args = ["HYPRCURSOR_SIZE" "24"];}
      ];

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
          allow_tearing = true; # opt-in per-window below, for games
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
          vrr = 1; # adaptive sync on fullscreen
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
        # Games: no rounding, no blur, allow tearing (lower latency).
        {
          match.class = "^(steam_app_.*)$";
          immediate = true;
          fullscreen = true;
          no_blur = true;
          rounding = 0;
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
      workspace_rule = [
        {
          workspace = "special:music";
          on_created_empty = "pear-desktop";
        }
        {
          workspace = "special:communication";
          on_created_empty = "discord";
        }
      ];
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
        hl.exec_cmd("sleep 1 && ${pkgs.gammastep}/bin/gammastep -l 49.61:6.13") -- Luxembourg
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
      hl.bind(mod .. " + M", hl.dsp.workspace.toggle_special("music"))
      hl.bind(mod .. " + D", hl.dsp.workspace.toggle_special("communication"))

      -- ---- Capture ----
      -- `caelestia record` drives gpu-screen-recorder, which is installed with
      -- its setuid helper by programs.gpu-screen-recorder in the system config.
      hl.bind("Print", hl.dsp.exec_cmd("caelestia screenshot"))
      hl.bind(mod .. " + SHIFT + S",       hl.dsp.global("caelestia:screenshotFreeze"))
      hl.bind(mod .. " + SHIFT + ALT + S", hl.dsp.global("caelestia:screenshot"))
      hl.bind("CTRL + ALT + R",            hl.dsp.exec_cmd("caelestia record"))
      hl.bind(mod .. " + ALT + R",         hl.dsp.exec_cmd("caelestia record -s"))
      hl.bind(mod .. " + SHIFT + C",       hl.dsp.exec_cmd("hyprpicker -a"))

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
