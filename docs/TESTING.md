# Testing this config before you wipe anything

Three tiers, cheapest first. **Tier 1 catches almost everything I'd worry
about** and takes minutes — do it before you spend an hour on a VM install.

None of this touches your disks.

---

## Tier 1 — does it evaluate? (~5 min)

Most of the risk in a fresh NixOS config is *evaluation* errors: a renamed
option, a package attribute that doesn't exist, a typo in a module. You do not
need a VM to find those. You need `nix`.

### Install nix on the current CachyOS system

You are wiping this machine anyway, so this costs you nothing:

```sh
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Then open a new shell and enable flakes:

```sh
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

### Force a full evaluation

```sh
cd ~/nixos-config

# Evaluating the toplevel derivation path walks the ENTIRE module system —
# every option, every package reference, both hosts. If this prints a store
# path, the config is sound. If it errors, the message names the exact file.
nix eval --raw .#nixosConfigurations.nixos-vm.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.julien-desktop.config.system.build.toplevel.drvPath
```

`--raw` keeps the output to one line. Errors come with a file and line number;
fix, re-run, repeat. This loop is seconds long once the flake inputs are fetched.

### See what would be built, without building it

```sh
nix build .#nixosConfigurations.julien-desktop.config.system.build.toplevel --dry-run
```

Anything listed under "will be built" rather than "will be fetched" is
compiling locally — expect `caelestia-shell` and `quickshell` there, and not
much else.

### Get the one missing hash

```sh
./scripts/update-hashes.sh
```

This is the `npmDepsHash` for nxapi that has to be discovered by building once.
Commit the result. You can do it here on CachyOS — it is just a hash, it
transfers.

---

## Tier 2 — does it boot and render? (~30 min, mostly download)

Nix can build a QEMU virtual machine out of the config **and pull QEMU in as
part of the closure**, so there is nothing to install:

```sh
cd ~/nixos-config
nix build .#nixosConfigurations.nixos-vm.config.system.build.vm
./result/bin/run-nixos-vm-vm
```

Log in as `julien` / `nixos`.

This is the test worth doing. virtio-gpu gives the guest a real DRM render node,
so **Hyprland and Caelestia actually come up** and you can click around the bar,
open the launcher, check the theming.

The VM's disk image (`nixos-vm.qcow2`) is created in whatever directory you ran
it from. Delete it to start clean; `rm nixos-vm.qcow2`.

If it fails with a GL error, edit `virtualisation.vmVariant.virtualisation.qemu.options`
in `hosts/vm/default.nix` down to `-device virtio-vga` / `-display gtk` and
rebuild. You lose acceleration; it still boots.

### What this VM does NOT test

Deliberately, because none of the hardware is present:

| Not tested | Why | Where it lives |
|---|---|---|
| NVIDIA driver | no 4090 in the VM | `modules/nixos/nvidia.nix` |
| Elgato loopback | no capture card | `home/services/elgato-monitor.nix` |
| liquidctl | no Kraken, no Lian Li hub | `modules/nixos/liquidctl.nix` |
| nxapi | needs a Nintendo login | `home/services/nxapi.nix` |
| Steam / Proton | several GB, no GPU | `modules/nixos/gaming.nix` |
| amd_pstate, V-Cache | no real CPU | `modules/nixos/cpu.nix` |

The VM host simply doesn't import those modules — see the import list in
`hosts/vm/default.nix` versus `hosts/desktop/default.nix`.

The `discord_feed` null sink **is** tested: it is pure PipeWire config and needs
no hardware. Check it in the VM with:

```sh
pactl list short sinks | grep discord_feed
```

---

## Tier 3 — VirtualBox

You have VirtualBox installed, so this is tempting. It is the worst of the three
options, and you should know why before you spend time on it.

> ⚠ **Hyprland will not start under VirtualBox.** VBoxSVGA and VMSVGA do not
> expose a DRM render node that Hyprland's backend (aquamarine) can open. You
> get "no DRM devices found" and the session dies instantly. This is a
> VirtualBox limitation, not a bug in this config — the same ISO behaves the
> same way with any Hyprland setup.

What you *can* validate: the installer steps in [INSTALL.md](INSTALL.md), the
boot chain, systemd-boot, and that greetd reaches a login prompt. That is real
value if what you want to rehearse is the install procedure rather than the
desktop.

VM settings that matter:

| Setting | Value | Why |
|---|---|---|
| System → Motherboard → **Enable EFI** | **ON** | systemd-boot is UEFI-only. This is the #1 way to waste an hour. |
| Memory | 8192 MB | |
| Processors | 6 | |
| Disk | 40 GB | /nix with Qt in it is not small |
| Display → Video Memory | 128 MB | |

Then follow [INSTALL.md](INSTALL.md), with one change: the VM has a single disk,
so use the **`nixos-vm`** host, which mounts by label and needs no UUID editing:

```sh
# single disk, /dev/sda
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI"   /dev/sda
sgdisk -n 2:0:0   -t 2:8300 -c 2:"nixos" /dev/sda

mkfs.fat -F32 -n BOOT /dev/sda1
mkfs.btrfs -f -L nixos /dev/sda2      # label "nixos" — hosts/vm expects it

mount /dev/sda2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

mount -o subvol=@,compress=zstd:1,noatime     /dev/sda2 /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o subvol=@home,compress=zstd:1,noatime /dev/sda2 /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime  /dev/sda2 /mnt/nix
mount /dev/sda1 /mnt/boot

nixos-install --flake /mnt/etc/nixos#nixos-vm \
  --option experimental-features 'nix-command flakes'
```

---

## Reading a failure

**`error: attribute 'foo' missing`** — a package or option name that doesn't
exist. The trace names the file. Cross-check the name at
<https://search.nixos.org>.

**`The option 'x.y.z' does not exist`** — an option was renamed or removed
upstream. The error usually suggests the new name.

**`hash mismatch in fixed-output derivation`** — expected for `nxapi` (see Tier
1) and for `curseforge` after any upstream release
(`./scripts/update-curseforge.sh`). Not expected for anything else.

**`infinite recursion encountered`** — almost always a module referring to
`config.something` that it also defines. Nothing in this repo should do that;
if you see it, it's a real bug — tell me the trace.
