{pkgs, ...}: {
  users.users.julien = {
    isNormalUser = true;
    description = "Julien";
    shell = pkgs.fish;
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video" # /dev/video0 — required to open the Elgato 4K X in OBS
      "audio"
      "input"
      # NOTE: no "storage"/"plugdev" here — those are Arch groups and do not
      # exist on NixOS; listing them makes the whole evaluation fail. The Kraken
      # and the Lian Li hub are driven by a root service, so no user-level USB
      # HID access is needed anyway.
    ];
  };

  # fish must be enabled system-wide as well, or it is not a valid login shell
  # and `users.users.julien.shell` silently gives you a broken session.
  programs.fish.enable = true;

  # No password prompt for a single-user desktop is a matter of taste; the
  # default (prompt, with a timeout) is kept. wheel gets sudo:
  security.sudo.execWheelOnly = true;

  # Polkit is what lets the graphical session authenticate privileged actions
  # (mounting disks, NetworkManager changes) without a terminal.
  security.polkit.enable = true;
}
