# Install day

Start to finish, from the NixOS ISO to a working Hyprland + Caelestia desktop.

Target: MSI MAG X670E Carbon WiFi / Ryzen 9 7950X3D / RTX 4090 / 64 GB DDR5 /
2× WD SN850X (1 TB + 2 TB).

> **This wipes both NVMe drives.** That was the decision: one btrfs pool spanning
> both, clean slate, nothing carried over. The ~140 GB Steam library re-downloads.
> Nothing below is reversible after step 3.

---

## 0. Before you boot the ISO

**BIOS/UEFI:**

| Setting | Value | Why |
|---|---|---|
| Secure Boot | **Disabled** | The NVIDIA kernel module is not signed |
| CSM | **Disabled** | Pure UEFI — systemd-boot needs it |
| Above 4G Decoding | **Enabled** | Resizable BAR for the 4090 |
| Re-Size BAR Support | **Enabled** | |
| EXPO/DOCP | Enabled | You paid for the DDR5 speed |

Plug the **Elgato 4K X into a USB 3.x (blue, 10 Gbps) port**. On USB 2 it still
enumerates but silently drops to low resolutions.

The ISO you already have on the USB stick (`nixos-graphical-26.05-x86_64`) is
fine. We will **not** use its graphical installer — it writes its own
`configuration.nix` and knows nothing about this flake. Everything below is done
from a terminal.

---

## 1. Boot and get a network

Boot the stick, open a terminal, become root:

```sh
sudo -i
```

Wired (RTL8125) should already have DHCP. For Wi-Fi (MT7922):

```sh
systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "YOUR_SSID"
> set_network 0 psk "YOUR_PASSWORD"
> enable_network 0
> quit
```

Confirm:

```sh
ping -c3 cache.nixos.org
```

---

## 2. Identify the drives

```sh
lsblk -o NAME,SIZE,MODEL,FSTYPE
```

You are looking for:

- `nvme0n1` — **931.5 G** (the 1 TB SN850X) → gets the ESP and the first pool member
- `nvme1n1` — **1.8 T** (the 2 TB SN850X) → becomes the second pool member, whole-disk

> ⚠ **Confirm the sizes before typing anything below.** If `nvme0n1` is the 2 TB
> on your boot, swap the names throughout. Getting this backwards puts a 4 GB ESP
> on the wrong disk — recoverable, but annoying.

---

## 3. Partition and format

### 3.1 Wipe

```sh
wipefs -a /dev/nvme0n1
wipefs -a /dev/nvme1n1
sgdisk --zap-all /dev/nvme0n1
sgdisk --zap-all /dev/nvme1n1
```

### 3.2 Partition the 1 TB

The 2 TB gets **no partition table at all** — btrfs goes straight onto the raw
device, exactly as it is set up today.

```sh
sgdisk -n 1:0:+4G -t 1:ef00 -c 1:"EFI"   /dev/nvme0n1
sgdisk -n 2:0:0   -t 2:8300 -c 2:"nixos" /dev/nvme0n1
partprobe /dev/nvme0n1
```

4 GB for the ESP is generous on purpose: every NixOS generation keeps a kernel
and an initrd there, and NVIDIA initrds are not small. `configurationLimit = 20`
in `modules/nixos/boot.nix` keeps it bounded.

### 3.3 Make the filesystems

```sh
mkfs.fat -F32 -n BOOT /dev/nvme0n1p1

# One filesystem across BOTH devices.
#   -d single : data is spread, not mirrored → 2.8 TB usable
#   -m raid1  : metadata IS mirrored (the mkfs default for multi-device)
mkfs.btrfs -f -L nixos -d single -m raid1 /dev/nvme0n1p2 /dev/nvme1n1
```

Verify both members showed up:

```sh
btrfs filesystem show
# Total devices 2 ... devid 1 /dev/nvme0n1p2 ... devid 2 /dev/nvme1n1
```

### 3.4 Subvolumes

```sh
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
umount /mnt
```

### 3.5 Mount

```sh
OPTS="compress=zstd:1,noatime,ssd,discard=async,space_cache=v2"

mount -o subvol=@,$OPTS          /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{home,nix,var/log,.snapshots,boot}
mount -o subvol=@home,$OPTS      /dev/nvme0n1p2 /mnt/home
mount -o subvol=@nix,$OPTS       /dev/nvme0n1p2 /mnt/nix
mount -o subvol=@log,$OPTS       /dev/nvme0n1p2 /mnt/var/log
mount -o subvol=@snapshots,$OPTS /dev/nvme0n1p2 /mnt/.snapshots
mount -o fmask=0077,dmask=0077   /dev/nvme0n1p1 /mnt/boot
```

Sanity check — every line should say `btrfs` except `/mnt/boot`:

```sh
findmnt -R /mnt
```

---

## 4. Get the config onto the machine

**The GitHub repo is private, so you cannot clone it from the installer** — the
ISO has no credentials, and the SSH key that can read it lives on the drive you
are about to erase. Copy the repo to a USB stick *before* you wipe:

```sh
# ── on CachyOS, BEFORE the install ──
# 252 KB. Any USB stick will do; it does not have to be the ISO one.
cp -r ~/nixos-config /run/media/julien/<STICK>/nixos-config
sync
```

Then, from the NixOS ISO:

```sh
mkdir -p /mnt/etc/nixos
cp -r /run/media/<STICK>/nixos-config/. /mnt/etc/nixos/
cd /mnt/etc/nixos
```

<details><summary>Alternative: bring the SSH key instead of the repo</summary>

If you would rather clone fresh, copy `~/.ssh/id_ed25519` to the stick as well
and put it in place on the installer:

```sh
mkdir -p ~/.ssh && cp /run/media/<STICK>/id_ed25519 ~/.ssh/
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519
nix-shell -p git
git clone git@github.com:krier-julien/nixos-config.git /mnt/etc/nixos
```

That private key is a credential — treat the stick accordingly, and delete the
copy afterwards.

</details>

### 4.1 Fill in the two UUIDs

```sh
lsblk -o NAME,FSTYPE,UUID
```

Both `nvme0n1p2` and `nvme1n1` will show **the same** btrfs UUID — that is
correct, it is one filesystem. Put that one in as the pool UUID, and the
`vfat` UUID from `nvme0n1p1` as the ESP.

```sh
nano hosts/desktop/disks.nix
#   pool = "/dev/disk/by-uuid/<the btrfs UUID>";
#   esp  = "/dev/disk/by-uuid/<the vfat UUID>";
```

There is nothing else to edit. Hostname, user, locale, timezone and keymap are
already set for this machine.

> **If you cloned with git:** Nix flakes only see files that git *tracks*.
> Modifying a tracked file (like `disks.nix`) is fine — a dirty tree is read
> normally. But a brand-new file you forgot to `git add` is invisible to the
> build and you get a baffling "file not found". If you copied the directory off
> a USB stick without `.git`, this doesn't apply at all.

### 4.2 Lock the inputs

```sh
nix flake lock --extra-experimental-features 'nix-command flakes'
```

Doing this as its own step means input-fetching failures (a network blip, a
GitHub rate limit) surface here rather than 20 minutes into the install. It
writes `flake.lock`, which is what pins Caelestia and nixpkgs to exact
revisions — commit it.

---

## 5. Install

```sh
nixos-install \
  --flake /mnt/etc/nixos#julien-desktop \
  --option experimental-features 'nix-command flakes'
```

It prompts for a **root password** at the end. Set one, and don't skip it —
`security.sudo.execWheelOnly` plus a greeter that only offers `julien` means a
root password is your way back in if the next step goes wrong.

This pulls a lot — NVIDIA, Steam's 32-bit stack, Qt for Quickshell. Expect a
while on a good connection.

Then set julien's password — without this you cannot log in at the greeter:

```sh
nixos-enter --root /mnt -c 'passwd julien'
```

> **This whole configuration was built end to end before the install**, on the
> old CachyOS system with nix installed alongside it. Both hosts evaluate clean
> and every package builds, including the two custom ones. What you are running
> here is not a first attempt.

Then:

```sh
reboot
```

Pull the USB stick.

---

## 6. First boot

You should land on **SDDM** with the astronaut theme. Log in as `julien`.

> **Check the session picker once.** `programs.hyprland.withUWSM` installs two
> session entries, `Hyprland` and `Hyprland (uwsm-managed)`. The config
> pre-selects the uwsm one via `services.displayManager.defaultSession`, and
> SDDM remembers your last choice afterwards — but if you ever pick the plain
> one, `graphical-session.target` is never reached and **nxapi silently stops
> working**. That is the first thing to check if the Switch presence disappears.

If you get a black screen instead, switch to a TTY with `Ctrl+Alt+F2` and read:

```sh
journalctl -b -u display-manager
journalctl --user -b -u caelestia
```

**If it never gets that far** — plymouth hides the boot messages by design. At
the systemd-boot menu press `e` to edit the kernel command line for one boot,
delete `quiet` and `splash`, and press Enter. You will see exactly where it
stops. `boot.shell_on_fail` is already in the kernel params, so a stage-1
failure drops you to a shell rather than hanging.

**If the desktop is broken but the machine boots**, pick the previous generation
from the systemd-boot menu. Nothing a bad `nixos-rebuild switch` does is
permanent.

---

## 7. The two things that need doing by hand

Everything else in this repo is declarative. These two are not, because one is a
Nintendo login and the other is an OBS GUI.

### 7.1 Authenticate nxapi

Remember the second-account trick: Nintendo will not report your own presence to
your own session, so nxapi logs in as a **secondary account that is friends with
your main one** and watches the main account.

```sh
nxapi nso auth        # log in as the SECONDARY account
nxapi nso friends     # find the MAIN account's NSA ID
```

The repo already has `6a3756fd9acdec95` in `home/services/nxapi.nix`. If that is
still your main account's NSA ID, nothing to change.

```sh
systemctl --user restart nxapi
journalctl --user -u nxapi -f
```

Check the user agent survived systemd's whitespace splitting — the full string,
spaces and all, must come back on one line:

```sh
systemctl --user show nxapi.service -p Environment
```

If `nxapi nso auth` fails right after you paste the token link with:

```
Error: Remote configuration prevents Coral authentication
```

the packaged nxapi is too old, not your token. nxapi fetches a config from
upstream before logging in, and upstream refuses Coral authentication to clients
that predate Nintendo's current app version. npm's `latest` tag for nxapi is
still the March 2023 release, so `pkgs/nxapi/default.nix` tracks the `next`
prerelease channel instead — bump it there (the comment at the top of that file
has the two commands) and rerun `./scripts/update-hashes.sh`.

### 7.2 Configure OBS

Full detail is in the comments at the bottom of `home/programs/obs.nix`. The one
setting that matters:

**Settings → Audio → Advanced → Monitoring Device → `Discord Feed (OBS monitor)`**

That is the switch that sends OBS's monitoring output into the null sink instead
of your headset. Point it at the headset and you hear the Switch twice.

---

## 8. Verify

Work down this list. Each line either prints what it should or tells you exactly
what is broken.

### Hardware

```sh
# GPU
nvidia-smi                       # RTX 4090, driver 6xx
vulkaninfo --summary | head      # no errors
vainfo                           # hardware decode present

# CPU
cat /sys/devices/system/cpu/amd_pstate/status        # active
cat /sys/devices/system/cpu/amd_x3d_vcache/mode      # cache
systemctl status amd-x3d-vcache-mode

# Cooling — this is the one that was silently broken on the old machine
systemctl is-enabled liquidctl                       # enabled
systemctl status liquidctl                           # exited, no errors
sudo liquidctl --unsafe=EXPERIMENTAL --match kraken status
sudo liquidctl --match "uni sl" status
```

### Capture card

```sh
lsusb | grep -i elgato           # 0fd9:009b
lsusb -t | grep -i elgato        # must say 5000M or 10000M, not 480M
v4l2-ctl --list-devices          # /dev/video0
id -nG | tr ' ' '\n' | grep video
```

### Audio — the important one

```sh
# The null sink must exist BEFORE you start OBS
pactl list short sinks | grep discord_feed

# The Elgato source, and the loopback service
pactl list short sources | grep -i elgato
systemctl --user status elgato-monitor

# EXACTLY ONE loopback. Two is the "hearing it twice" bug at double volume.
pgrep -a -f pw-loopback
```

Turn the Switch on. You should hear it, with OBS closed.

If the node names in `home/services/elgato-monitor.nix` don't match what
`pactl` reports (the Elgato's serial is baked into its node name), update them
there and rebuild — don't paper over it with a hand-run `pw-loopback`.

Visual check of the whole graph:

```sh
qpwgraph
```

You want two consumers of the Elgato source, terminating in **different** places:
one at the headset sink, one at `discord_feed`.

### Session

```sh
systemctl --user status caelestia          # the shell
echo $XDG_CURRENT_DESKTOP                  # Hyprland
systemctl --user list-units 'graphical-session.target'   # active (proves uwsm works)
```

That last one matters: if `graphical-session.target` is not active, uwsm didn't
start the session properly and `nxapi.service` will never run.

---

## 9. Day-to-day

```sh
rebuild        # sudo nixos-rebuild switch --flake ~/nixos-config#julien-desktop
rebuild-test   # try it without making it the boot default
update         # nix flake update
whatchanged    # nvd diff — what actually changed between generations
```

If a rebuild leaves you with a broken desktop, pick the previous generation from
the systemd-boot menu at boot. Nothing is destroyed by a bad switch.

**CurseForge stops building?** That is expected — upstream publishes only a
"latest" URL, so the pinned hash goes stale on every release:

```sh
./scripts/update-curseforge.sh
```
