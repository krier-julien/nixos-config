# nixos-config

NixOS configuration for a single desktop: **Hyprland + Caelestia**, on a
Ryzen 9 7950X3D / RTX 4090 / 64 GB DDR5 / 2× WD SN850X box.

Installing from scratch? → **[docs/INSTALL.md](docs/INSTALL.md)**

---

## What this builds

- NixOS unstable, systemd-boot, `linux_zen`
- One btrfs pool spanning both NVMe drives, zstd:1, zram swap
- Hyprland under **uwsm**, greeted by **SDDM** with the `sddm-astronaut` theme
- **Caelestia** shell — bar, launcher, dashboard, notifications, lock screen,
  and Material You colours generated from the wallpaper. Built from
  [AdiAmbassador's forks](https://github.com/AdiAmbassador/caelestia-aw) rather
  than upstream, for animated wallpapers
- NVIDIA open kernel modules, Wayland-native
- Steam + gamescope + gamemode + ProtonPlus + MangoHud, ntsync on, CurseForge,
  Discord, OBS, Plezy, Pear Desktop
- The three hardware integrations this machine actually exists for:
  the **Elgato 4K X audio routing**, **liquidctl** fan/pump control, and
  **nxapi** Switch Rich Presence

## Layout

```
flake.nix                      inputs, the overlay, the one host
hosts/desktop/
  default.nix                  hostname + which hardware modules to pull in
  hardware-configuration.nix   kernel modules, firmware — read off the live hw
  disks.nix                    the btrfs pool  ← the only file you edit at install
modules/nixos/
  default.nix                  the hardware-agnostic set
    boot networking locale users nix-settings desktop audio fonts
  cpu nvidia capture liquidctl gaming    ← this machine only, pulled in by the host
home/
  default.nix                  the only home entry point
  caelestia.nix                the shell, plus the two package fixes it needs
  hyprland.nix                 the compositor config — ours, not Caelestia's
  theme.nix                    GTK/Qt/cursor scaffolding for Caelestia to recolour
  programs/                    apps, shell, terminal, obs, mangohud
  services/                    browser-clean-exit, elgato-monitor, nxapi
pkgs/                          things nixpkgs doesn't have
  curseforge/                  AppImage, wrapped
  nxapi/                       npm, with a committed runtime-only lockfile
scripts/                       hash refreshers
docs/INSTALL.md                install day, start to finish
```

There is one host, `julien-desktop`: the real machine, 7950X3D + 4090 + Elgato
+ Kraken. There used to be a test VM alongside it; it was removed once the real
machine was running, since a VM with no GPU and no capture card could not
exercise the parts worth testing.

## Rebuilding

```sh
sudo nixos-rebuild switch --flake ~/nixos-config#julien-desktop
```

Or the fish aliases: `rebuild`, `rebuild-test`, `rebuild-boot`, `update`,
`whatchanged`.

## Keyboard shortcuts

`SUPER` is the mod key throughout. Every bind below is declared in
`home/hyprland.nix` — this table is a copy for reading, not the source of
truth, so if the two ever disagree the Nix file wins.

Binds marked 🔒 keep working while the lock screen is up.

### Shell — Caelestia

| Keys | Does |
|---|---|
| `SUPER` (tap and release) | Launcher |
| `SUPER` + `N` | Sidebar / dashboard |
| `SUPER` + `K` | Show all windows (overview) |
| `SUPER` + `L` | Lock the screen |
| `CTRL` + `ALT` + `C` | Clear all notifications |
| `CTRL` + `ALT` + `Delete` | Session menu (log out / reboot / shut down) |
| `CTRL` + `SUPER` + `ALT` + `R` | Restart the shell (after a bad QML reload) |
| `CTRL` + `SUPER` + `SHIFT` + `R` | Kill the shell |

### Apps

| Keys | Does |
|---|---|
| `SUPER` + `T` | Terminal (foot) |
| `SUPER` + `W` | Browser (Brave Origin) |
| `SUPER` + `E` | File manager (Thunar) |
| `CTRL` + `ALT` + `V` | Volume mixer (pwvucontrol) |

### Windows

| Keys | Does |
|---|---|
| `SUPER` + `Q` | Close |
| `SUPER` + `F` | Toggle fullscreen — also how you rescue a launcher that got forced fullscreen |
| `SUPER` + `P` | Pin (keep on top, across workspaces) |
| `SUPER` + `ALT` + `Space` | Toggle floating |
| `CTRL` + `SUPER` + `\` | Centre a floating window |
| `SUPER` + `←` `→` `↑` `↓` | Move focus |
| `SUPER` + `SHIFT` + `←` `→` `↑` `↓` | Move the window |
| `SUPER` + `-` / `=` | Shrink / grow the window |
| `SUPER` + left-drag | Move a window with the mouse |
| `SUPER` + right-drag | Resize a window with the mouse |

### Groups (tabbed windows)

| Keys | Does |
|---|---|
| `SUPER` + `,` | Group / ungroup the focused window |
| `SUPER` + `U` | Pull the window out of its group |
| `ALT` + `Tab` | Next window in the group |
| `CTRL` + `ALT` + `Tab` | Previous window in the group |

### Workspaces

Five apps autostart at login, one per workspace, and a window rule keeps them
there even when you launch them by hand later:

| Workspace | App |
|---|---|
| 1 | Brave Origin |
| 2 | Discord |
| 3 | Steam |
| 4 | OBS Studio |
| 5 | Pear Desktop |

| Keys | Does |
|---|---|
| `SUPER` + `1`…`9`, `0` | Go to workspace 1–10 |
| `SUPER` + `ALT` + `1`…`9`, `0` | Send the window to workspace 1–10 |
| `SUPER` + scroll wheel | Next / previous workspace |
| `SUPER` + `D` | Jump to Discord (workspace 2) |
| `SUPER` + `M` | Jump to music, i.e. Pear Desktop (workspace 5) |
| `SUPER` + `S` | Toggle the special (scratchpad) workspace |

The bar draws six slots: the five apps above plus one empty workspace to work
in. `SUPER`+`6` lands on the spare with the other five still on screen.

Workspaces 7–10 still exist and the binds still reach them, but the bar pages
in blocks of six, so going to 7 swaps the row for 7–12. It is a fixed-width
widget, not Niri-style dynamic workspaces — `home/caelestia.nix` says what it
would take to change that.

### Screenshots, recording, colours

| Keys | Does |
|---|---|
| `Print` | Screenshot |
| `SUPER` + `SHIFT` + `S` | Region screenshot, screen frozen while you select |
| `SUPER` + `SHIFT` + `ALT` + `S` | Region screenshot, screen live |
| `CTRL` + `ALT` + `R` | Start / stop recording |
| `SUPER` + `ALT` + `R` | Start / stop recording a region |
| `SUPER` + `SHIFT` + `C` | Colour picker (hyprpicker, copies to clipboard) |

### Clipboard and emoji

| Keys | Does |
|---|---|
| `SUPER` + `V` | Clipboard history |
| `SUPER` + `.` | Emoji picker |

### Wallpaper

| Keys | Does |
|---|---|
| `SUPER` + `SHIFT` + `W` | Open the shell's wallpaper picker (stills and animated) |

### In games (MangoHud, not Hyprland)

These are handled by the MangoHud overlay itself, so they only work inside a
game. Configured in `home/programs/mangohud.nix`.

| Keys | Does |
|---|---|
| `Left Shift` + `` ` `` | Show / hide the overlay (hidden by default) |
| `Left Shift` + `F1` | Toggle the 117 fps cap |
| `Left Shift` + `F2` | Start / stop logging |

### Media and volume

| Keys | Does |
|---|---|
| `CTRL` + `SUPER` + `Space` | Play / pause 🔒 |
| `CTRL` + `SUPER` + `=` / `-` | Next / previous track 🔒 |
| `Play` / `Next` / `Prev` media keys | Same 🔒 |
| `SUPER` + `SHIFT` + `M`, or `Mute` | Mute output 🔒 |
| `MicMute` | Mute the microphone 🔒 |
| `Volume Up` / `Volume Down` | Output volume, ±5% |

## Design notes

**Caelestia owns the shell; this repo owns the compositor.** The Caelestia
flake supplies the Quickshell bar, launcher, lock screen and theming engine.
`home/hyprland.nix` is hand-written here, seeded from Caelestia's own keybinds
so muscle memory carries over. The community "full dots" ports bundle a
Hyprland config too, but the most complete one is archived and self-described as
very experimental — not a base for a daily driver.

**uwsm is load-bearing, not cosmetic.** It is what makes
`graphical-session.target` actually get reached, and `nxapi.service` is bound to
that target. Drop uwsm and the Rich Presence silently stops working.

**The Elgato audio design is two paths that end in different places.** An
always-on `pw-loopback` to the headset, and OBS monitoring into a null sink that
only Discord reads. That separation is the entire reason the Switch
isn't heard twice. Both halves are documented at length in
`modules/nixos/audio.nix` and `home/services/elgato-monitor.nix` — read those
before changing either.

**VRR is fullscreen-only and tearing is off, on purpose.** The panel is a 55"
LG G3, a WOLED whose brightness varies slightly with refresh rate — so
always-on VRR makes the desktop flicker any time something animates at an odd
frame rate. `misc:vrr = 2` confines G-Sync to a fullscreen window, i.e. to
games. Tearing is the other half: it only buys latency in competitive play, and
with VRR on it actively misbehaves when a game runs past the panel maximum, so
`general:allow_tearing` is `false` and no window opts in. Both live in
`home/hyprland.nix`, with the reasoning next to them. Enable VRR/G-Sync on the
TV as well (Game Optimiser), and cap in-game frame rates just under the panel
maximum — VRR does nothing above it.

**Steam launch options are set once, not per game.** Steam's per-game "Launch
Options" box lives in Steam's own mutable config, where nothing here can reach
it. `programs.steam.package = pkgs.steam.override { extraEnv = …; }` is the
declarative equivalent — the variables are exported inside Steam's FHS
environment, so every game inherits them and the box stays empty.
`modules/nixos/gaming.nix` uses it for two things: `PROTON_USE_NTSYNC=1`, and
`MANGOHUD=1` for the frame cap. gamemode and gamescope are wrappers rather
than variables, so `gamemoderun %command%` remains a per-game option.

**The frame cap is the reason MangoHud is installed.** VRR does nothing above
the panel maximum, so every game wants a limit a few frames short of it —
`home/programs/mangohud.nix` sets 117 once, for everything, with the overlay
itself hidden (`Left Shift`+`` ` `` shows it). MangoHud is also injected into
Steam's FHS through `extraPkgs`: the Vulkan layer has to exist inside the
pressure-vessel container, and `MANGOHUD=1` without it is the usual reason the
overlay appears to do nothing on NixOS.

**Animated wallpapers are the shell's job, not a service beside it.** Stills
go in `~/Images/wallpapers`, videos in `~/Images/wallpapers/Animated`, and the
picker (`SUPER`+`SHIFT`+`W`) shows them as two categories with thumbnails and a
live preview. Picking either regenerates the Material You palette; for a video
the colours come from an extracted frame.

This is why the flake tracks
[AdiAmbassador's forks](https://github.com/AdiAmbassador/caelestia-aw) of the
Caelestia shell and CLI instead of upstream. It replaced a homegrown mpvpaper
service that drew video on the layer above Caelestia's own wallpaper — it
worked, but it was a second wallpaper system sitting next to the real one, with
its own fuzzel menu and its own idea of where wallpapers live.

The forks are Arch-first and their `nix/` directories came from upstream
untouched, so the packaging does not know about the feature it adds.
`home/caelestia.nix` closes the two gaps: QtMultimedia for the shell (the
renderer is `import QtMultimedia`, no mpv anywhere) and ffmpeg for the CLI
(thumbnails and palette extraction shell out to it). Both are runtime
dependencies, so a missing one builds fine and fails silently later — that file
says which symptom points at which.

**The machine locks but never sleeps.** Idle handling is the shell's, not
hypridle's — Caelestia moved it in-house, and a second idle daemon on the same
seat would fight it. `general.idle.timeouts` in `home/caelestia.nix` is the
whole policy, and because the list replaces rather than merges, what is written
there is all of it: lock at 10 minutes, and nothing else. Upstream's default
adds `dpms off` and then suspend-then-hibernate; both are deliberately gone.
Audio playback and any fullscreen window hold the chain off.
`services.logind.settings.Login.IdleAction = "ignore"` in
`modules/nixos/desktop.nix` covers the other thing that could suspend on a
timer. Suspending by hand still works — this is about the timer, not the
capability. The one thing to keep an eye on: with no `dpms off` step the lock
screen stays lit indefinitely, and the panel is a WOLED — the file records how
to put that step back if a ghost image ever appears.

**`liquidctl` matches devices by name, not index.** `-d 0` is a position in USB
enumeration order; a different kernel or port and you are sending
`set pump speed` to a fan hub. On the old machine this unit also sat
present-but-disabled for months, applying nothing. Declaring it in Nix makes
"installed" and "enabled" the same act.

## Known manual steps

Four things are not declarative, for reasons that are not fixable:

| What | Why | Where |
|---|---|---|
| `nxapi nso auth` | A Nintendo login flow | INSTALL.md §7.1 |
| OBS monitoring device | OBS keeps its config in a profile not worth generating | `home/programs/obs.nix` |
| Brave → Settings → Get started → On startup → **Continue where you left off** | A user preference in Brave's own mutable profile. `home/services/browser-clean-exit.nix` makes an ordinary reboot a clean exit, which is the real fix; this is the second line for a power cut or an OOM kill, and it costs one checkbox rather than an enterprise policy file and a "managed by your organisation" banner | `home/services/browser-clean-exit.nix` |
| `caelestia scheme set -n dynamic` | Deriving the palette from the wallpaper is a scheme you select once at runtime, not a config key | `home/caelestia.nix` |

Hashes are all real and committed. `scripts/update-hashes.sh` and
`scripts/update-curseforge.sh` exist for version bumps, not for first setup.

## Conservative choices for the first install

These picked the boring option on purpose, because a build failure during
`nixos-install` leaves you with no system and no generation to roll back to.
Each is a one-line change once the machine boots — the NVIDIA one has since
been taken:

| Setting | Now | Upgrade to |
|---|---|---|
| `boot.kernelPackages` | `linuxPackages` (nixpkgs default) | `linuxPackages_zen` |
| `hardware.nvidia.package` | ~~`nvidiaPackages.production`~~ → `.latest` (taken) | — |

nixpkgs only guarantees that the NVIDIA module compiles against the *default*
kernel. That is why the driver moved to `.latest` alone: pairing a zen kernel
with a newer driver is how you end up at a stage-1 shell. If a rebuild ever dies
compiling the NVIDIA module, put `.production` back.

CurseForge's pinned hash also goes stale on every upstream release, because they
publish only a "latest" URL. `scripts/update-curseforge.sh` re-pins it.
