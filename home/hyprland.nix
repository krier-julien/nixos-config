# Hyprland — the compositor config. This file is YOURS: Caelestia supplies the
# shell (bar/launcher/lockscreen), not the window manager rules.
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

    settings = {
      # ── Monitors ────────────────────────────────────────────────────────
      # `preferred,auto,1` is a safe catch-all. Replace once you know the real
      # names — `hyprctl monitors` prints them. Example for a 1440p240 primary:
      #   monitor = "DP-1,2560x1440@240,0x0,1";
      monitor = [",preferred,auto,1"];

      # ── Autostart ───────────────────────────────────────────────────────
      # Caelestia's shell is NOT started here — it runs as a systemd user
      # service (see ./caelestia.nix), which is why it survives a crash.
      exec-once = [
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store"
        "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store"
        "${pkgs.bluez}/bin/mpris-proxy" # bluetooth headset media keys → MPRIS
        "sleep 1 && ${pkgs.gammastep}/bin/gammastep -l 49.61:6.13" # Luxembourg
      ];

      # ── Environment ─────────────────────────────────────────────────────
      # The NVIDIA/toolkit variables live in modules/nixos/nvidia.nix so they
      # apply to the greeter and to non-Hyprland sessions too. Only genuinely
      # compositor-scoped things belong here.
      env = [
        "XCURSOR_THEME,Bibata-Modern-Classic"
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(cba6f7ff) rgba(89b4faff) 45deg";
        "col.inactive_border" = "rgba(45475aaa)";
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

      animations = {
        enabled = true;
        bezier = [
          "emphasized,0.2,0,0,1"
          "standard,0.2,0,0,1"
        ];
        animation = [
          "windows,1,3,emphasized,popin 80%"
          "border,1,5,standard"
          "fade,1,3,standard"
          "workspaces,1,4,emphasized,slide"
          "layers,1,3,standard,fade"
        ];
      };

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
        # NVIDIA workaround, but on current drivers it just costs you a frame of
        # cursor latency. Flip to true only if you actually see a broken cursor.
        no_hardware_cursors = false;
        inactive_timeout = 5;
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        smart_split = false;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
        vfr = true; # variable refresh: idle at low power
        vrr = 1; # adaptive sync on fullscreen
        focus_on_activate = true;
        new_window_takes_over_fullscreen = 2;
      };

      xwayland.force_zero_scaling = true;

      # ── Window rules ────────────────────────────────────────────────────
      windowrulev2 = [
        # Games: no rounding, no blur, allow tearing (lower latency), float-free.
        "immediate, class:^(steam_app_.*)$"
        "fullscreen, class:^(steam_app_.*)$"
        "noblur, class:^(steam_app_.*)$"
        "norounding, class:^(steam_app_.*)$"

        # Steam's own chrome misbehaves as a tiled window.
        "float, class:^(steam)$, title:^(Friends List)$"
        "float, class:^(steam)$, title:^(Steam Settings)$"

        # OBS projector/preview windows are more useful floating.
        "float, class:^(com.obsproject.Studio)$, title:^(.*Projector.*)$"

        # Picture-in-picture — matches Caelestia's own resizer rule.
        "float, title:^([Pp]icture[- ]in[- ][Pp]icture)$"
        "pin, title:^([Pp]icture[- ]in[- ][Pp]icture)$"
        "keepaspectratio, title:^([Pp]icture[- ]in[- ][Pp]icture)$"

        # Dialogs
        "float, class:^(pwvucontrol|qpwgraph|blueman-manager|nm-connection-editor)$"
        "float, title:^(Open File|Save File|Choose Files)$"

        # Inhibit the idle/lock timer while anything is fullscreen — stops the
        # lock screen appearing mid-game or mid-stream.
        "idleinhibit fullscreen, class:.*"
      ];

      layerrule = [
        "blur, caelestia-.*"
        "ignorezero, caelestia-.*"
      ];

      # ── Workspace assignment ────────────────────────────────────────────
      workspace = [
        "special:music, on-created-empty:pear-desktop"
        "special:communication, on-created-empty:discord"
      ];
    };

    # ── Keybinds ──────────────────────────────────────────────────────────
    # Kept in extraConfig rather than settings because bind lists read far
    # better as plain lines than as a Nix list of strings.
    extraConfig = ''
      $mod = SUPER

      # ---- Caelestia shell (global dispatchers registered by the shell) ----
      # Tap and release Super on its own to open the launcher.
      bindr = $mod, SUPER_L, global, caelestia:launcher
      bind  = $mod, N,       global, caelestia:sidebar
      bind  = $mod, K,       global, caelestia:showall
      bind  = $mod, L,       global, caelestia:lock
      bind  = CTRL ALT, C,   global, caelestia:clearNotifs
      bind  = CTRL ALT, Delete, global, caelestia:session

      # Restart / kill the shell when a QML reload goes wrong.
      bind = CTRL SUPER ALT,   R, exec, qs -c caelestia kill; sleep .1; caelestia shell -d
      bind = CTRL SUPER SHIFT, R, exec, qs -c caelestia kill

      # ---- Apps ----
      bind = $mod, T, exec, foot
      bind = $mod, W, exec, firefox
      bind = $mod, E, exec, thunar
      bind = CTRL ALT, V, exec, pwvucontrol

      # ---- Windows ----
      bind = $mod, Q, killactive
      bind = $mod, F, fullscreen, 0
      bind = $mod, P, pin
      bind = $mod ALT, Space, togglefloating
      bind = CTRL $mod, backslash, centerwindow

      bind = $mod, left,  movefocus, l
      bind = $mod, right, movefocus, r
      bind = $mod, up,    movefocus, u
      bind = $mod, down,  movefocus, d

      bind = $mod SHIFT, left,  movewindow, l
      bind = $mod SHIFT, right, movewindow, r
      bind = $mod SHIFT, up,    movewindow, u
      bind = $mod SHIFT, down,  movewindow, d

      bind = $mod, minus, resizeactive, -100 0
      bind = $mod, equal, resizeactive,  100 0

      bindm = $mod, mouse:272, movewindow
      bindm = $mod, mouse:273, resizewindow

      # ---- Groups ----
      bind = $mod, comma, togglegroup
      bind = $mod, U,     moveoutofgroup
      bind = ALT,  Tab,   changegroupactive, f
      bind = CTRL ALT, Tab, changegroupactive, b

      # ---- Workspaces ----
      bind = $mod, 1, workspace, 1
      bind = $mod, 2, workspace, 2
      bind = $mod, 3, workspace, 3
      bind = $mod, 4, workspace, 4
      bind = $mod, 5, workspace, 5
      bind = $mod, 6, workspace, 6
      bind = $mod, 7, workspace, 7
      bind = $mod, 8, workspace, 8
      bind = $mod, 9, workspace, 9
      bind = $mod, 0, workspace, 10

      bind = $mod ALT, 1, movetoworkspace, 1
      bind = $mod ALT, 2, movetoworkspace, 2
      bind = $mod ALT, 3, movetoworkspace, 3
      bind = $mod ALT, 4, movetoworkspace, 4
      bind = $mod ALT, 5, movetoworkspace, 5
      bind = $mod ALT, 6, movetoworkspace, 6
      bind = $mod ALT, 7, movetoworkspace, 7
      bind = $mod ALT, 8, movetoworkspace, 8
      bind = $mod ALT, 9, movetoworkspace, 9
      bind = $mod ALT, 0, movetoworkspace, 10

      bind = $mod, mouse_down, workspace, e+1
      bind = $mod, mouse_up,   workspace, e-1

      bind = $mod, S, togglespecialworkspace
      bind = $mod, M, togglespecialworkspace, music
      bind = $mod, D, togglespecialworkspace, communication

      # ---- Capture ----
      # `caelestia record` drives gpu-screen-recorder, which is installed with
      # its setuid helper by programs.gpu-screen-recorder in the system config.
      bind = , Print,             exec, caelestia screenshot
      bind = $mod SHIFT,     S,   global, caelestia:screenshotFreeze
      bind = $mod SHIFT ALT, S,   global, caelestia:screenshot
      bind = CTRL ALT,       R,   exec, caelestia record
      bind = $mod ALT,       R,   exec, caelestia record -s
      bind = $mod SHIFT,     C,   exec, hyprpicker -a

      # ---- Clipboard / emoji ----
      bind = $mod, V,      exec, pkill fuzzel || caelestia clipboard
      bind = $mod, period, exec, pkill fuzzel || caelestia emoji -p

      # ---- Media ----
      bindl = CTRL $mod, space, global, caelestia:mediaToggle
      bindl = CTRL $mod, equal, global, caelestia:mediaNext
      bindl = CTRL $mod, minus, global, caelestia:mediaPrev
      bindl = , XF86AudioPlay,  global, caelestia:mediaToggle
      bindl = , XF86AudioNext,  global, caelestia:mediaNext
      bindl = , XF86AudioPrev,  global, caelestia:mediaPrev

      bindl = $mod SHIFT, M, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindl = , XF86AudioMute,    exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindl = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      binde = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
      binde = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    '';
  };
}
