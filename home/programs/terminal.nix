# foot — Caelestia's terminal. It ships a themed foot config in its dots, and
# the CLI's `theme.enableTerm` recolours it live from the wallpaper.
#
# If you'd rather have kitty, swap the package here and change the $mod+T bind
# in ../hyprland.nix — nothing else in Caelestia depends on foot specifically.
{...}: {
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "CaskaydiaCove Nerd Font:size=11";
        pad = "8x8";
      };
      scrollback.lines = 10000;
      mouse.hide-when-typing = "yes";

      # No [colors] block on purpose: `caelestia scheme` writes the palette into
      # foot's include file, and hardcoding colours here would fight it.
    };
  };
}
