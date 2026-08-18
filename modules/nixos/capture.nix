# Elgato 4K X — Switch 2 capture card.
#
# There is no driver and no firmware tool to install: the 4K X is a bog-standard
# UVC video device plus a standard USB-audio device, and `uvcvideo` /
# `snd_usb_audio` claim it at plug-in. There is no Elgato software for Linux and
# you do not need any.
#
# Plug it into a USB 3.x (10 Gbps) port. On USB 2 it still enumerates but
# silently drops to low resolutions — `lsusb -t` shows the negotiated speed, and
# `/proc/asound/cards` should say "super speed plus".
{pkgs, ...}: {
  # uvcvideo autoloads, but listing it means a missing module shows up as a boot
  # error rather than as "OBS can't see the card".
  boot.kernelModules = ["uvcvideo"];

  # NOT v4l2loopback — that creates *virtual* cameras. Reading a capture card
  # needs nothing extra.

  environment.systemPackages = with pkgs; [
    v4l-utils # v4l2-ctl --list-devices / --list-formats-ext
  ];

  # OBS itself is installed per-user in ../../home/programs/obs.nix, so that the
  # wrapped binary and its plugin set stay in one place. Installing it here too
  # would put an unwrapped `obs` earlier in PATH and lose the plugins.

  # Membership of `video` is what allows opening /dev/video0; it is granted in
  # ./users.nix. Verify after install with:  id -nG | tr ' ' '\n' | grep video
}
