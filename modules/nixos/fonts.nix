{pkgs, ...}: {
  fonts = {
    enableDefaultPackages = true;

    packages = with pkgs; [
      # Caelestia's own typefaces — the shell expects these by name and falls
      # back to something ugly without them.
      material-symbols
      rubik
      nerd-fonts.caskaydia-cove

      # General coverage
      noto-fonts
      noto-fonts-cjk-sans # Japanese/Chinese — game titles, nxapi presence text
      noto-fonts-emoji
      jetbrains-mono
      inter
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = ["Rubik" "Inter" "Noto Sans"];
        serif = ["Noto Serif"];
        monospace = ["CaskaydiaCove Nerd Font" "JetBrains Mono"];
        emoji = ["Noto Color Emoji"];
      };
      # Subpixel rendering — worth it on a desktop LCD.
      subpixel.rgba = "rgb";
      hinting.style = "slight";
    };
  };
}
