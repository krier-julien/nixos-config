# nixos-config

NixOS configuration for a single desktop: **Hyprland + Caelestia**, on a
Ryzen 9 7950X3D / RTX 4090 / 64 GB DDR5 / 2× WD SN850X box.

Installing from scratch? → **[docs/INSTALL.md](docs/INSTALL.md)**
Trying it out first? → **[docs/TESTING.md](docs/TESTING.md)**

---

## What this builds

- NixOS unstable, systemd-boot, `linux_zen`
- One btrfs pool spanning both NVMe drives, zstd:1, zram swap
- Hyprland under **uwsm**, greeted by **greetd + tuigreet**
- **Caelestia** shell from its official flake — bar, launcher, dashboard,
  notifications, lock screen, Material You colours generated from the wallpaper
- NVIDIA open kernel modules, Wayland-native
- Steam + gamescope + gamemode + ProtonPlus, CurseForge, Discord, OBS, Plezy,
  Pear Desktop
- The three hardware integrations this machine actually exists for:
  the **Elgato 4K X audio routing**, **liquidctl** fan/pump control, and
  **nxapi** Switch Rich Presence

## Layout

```
flake.nix                      inputs, the overlay, two hosts via mkHost
hosts/desktop/                 the real machine
  default.nix                  hostname + which hardware modules to pull in
  hardware-configuration.nix   kernel modules, firmware — hand-written from live hw
  disks.nix                    the btrfs pool  ← the only file you edit at install
hosts/vm/                      throwaway test VM: no GPU, no capture card, no AIO
modules/nixos/
  default.nix                  the common set, imported by BOTH hosts
    boot networking locale users nix-settings desktop audio fonts
  cpu nvidia capture liquidctl gaming    ← desktop-only, imported by that host
home/
  common.nix                   shared by both hosts (Caelestia, Hyprland, theme, shell)
  default.nix                  desktop: common + apps + obs + the two user services
  vm.nix                       VM: common + a handful of test packages
  caelestia.nix                the shell, via its official HM module
  hyprland.nix                 the compositor config — YOURS, not Caelestia's
  theme.nix                    GTK/Qt/cursor scaffolding for Caelestia to recolour
  programs/                    apps, shell, terminal, obs
  services/                    elgato-monitor, nxapi
pkgs/                          things nixpkgs doesn't have
  curseforge/                  AppImage, wrapped
  nxapi/                       npm, with a committed runtime-only lockfile
scripts/                       hash refreshers
docs/INSTALL.md                install day, start to finish
docs/TESTING.md                how to check this before wiping anything
```

## Hosts

| Attribute | What it is |
|---|---|
| `julien-desktop` | The real machine. 7950X3D + 4090 + Elgato + Kraken. |
| `nixos-vm` | A test VM. Same shell and desktop, none of the hardware modules. `nix build .#nixosConfigurations.nixos-vm.config.system.build.vm` builds a runnable QEMU image. |

## Rebuilding

```sh
sudo nixos-rebuild switch --flake ~/nixos-config#julien-desktop
```

Or the fish aliases: `rebuild`, `rebuild-test`, `rebuild-boot`, `update`,
`whatchanged`.

## Design notes

**Caelestia owns the shell; this repo owns the compositor.** The official
`caelestia-dots/shell` flake supplies the Quickshell bar/launcher/lockscreen and
the theming engine. `home/hyprland.nix` is hand-written here, seeded from
Caelestia's upstream keybinds so muscle memory carries over. The community "full
dots" ports bundle a Hyprland config too, but the most complete one is archived
and self-described as very experimental — not a base to build a daily driver on.

**uwsm is load-bearing, not cosmetic.** It is what makes
`graphical-session.target` actually get reached, and `nxapi.service` is bound to
that target. Drop uwsm and the Rich Presence silently stops working.

**The Elgato audio design is two paths that end in different places.** An
always-on `pw-loopback` to the headset, and OBS monitoring into a null sink that
only Discord reads. That separation is the entire reason the Switch isn't heard
twice. Both halves are documented at length in `modules/nixos/audio.nix` and
`home/services/elgato-monitor.nix` — read those before changing either.

**`liquidctl` matches devices by name, not index.** `-d 0` is a position in USB
enumeration order; a different kernel or port and you are sending
`set pump speed` to a fan hub. On the old machine this unit also sat
present-but-disabled for months, applying nothing. Declaring it in Nix makes
"installed" and "enabled" the same act.

## Known manual steps

Three things are not declarative, for reasons that are not fixable:

| What | Why | Where |
|---|---|---|
| `nxapi nso auth` | A Nintendo login flow | INSTALL.md §7.1 |
| OBS monitoring device | OBS keeps its config in a profile not worth generating | `home/programs/obs.nix` |

Hashes are all real and committed. `scripts/update-hashes.sh` and
`scripts/update-curseforge.sh` exist for version bumps, not for first setup.

## Conservative choices for the first install

Three places pick the boring option on purpose, because a build failure during
`nixos-install` leaves you with no system and no generation to roll back to.
All three are one-line changes once the machine boots:

| Setting | Now | Upgrade to |
|---|---|---|
| `boot.kernelPackages` | `linuxPackages` (nixpkgs default) | `linuxPackages_zen` |
| `hardware.nvidia.package` | `nvidiaPackages.production` | `.beta` / `.latest` |

nixpkgs only guarantees that the NVIDIA module compiles against the *default*
kernel. Pairing a zen kernel with a beta driver on install day is how you end up
at a stage-1 shell.

CurseForge's pinned hash also goes stale on every upstream release, because they
publish only a "latest" URL. `scripts/update-curseforge.sh` re-pins it.
