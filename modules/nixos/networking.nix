{...}: {
  networking.networkmanager = {
    enable = true;
    # iwd is a better 802.11 supplicant than wpa_supplicant for the MT7922 —
    # faster association, and it handles WPA3 without argument.
    wifi.backend = "iwd";
  };

  # NetworkManager wants its own DNS handling; systemd-resolved fights it.
  networking.useDHCP = false;

  networking.firewall = {
    enable = true;
    # Nothing listens by default. Open ports here as you need them, e.g.
    # allowedTCPPorts = [ 32400 ];  # if you ever run a Plex server locally
  };

  # Bluetooth — the board has it, and mpris-proxy (started by Hyprland) forwards
  # headset media keys into MPRIS.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
}
