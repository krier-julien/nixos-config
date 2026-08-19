# GTK/Qt/cursor theming.
#
# Caelestia generates a Material You palette from the wallpaper and applies it
# to GTK, Qt, btop, fuzzel and the Discord client — Equibop, through Equicord's
# theme directory (`cli.settings.theme.*` in ./caelestia.nix). What is set here
# is only the scaffolding it needs: an icon theme, a cursor, and a base GTK
# theme for it to recolour.
{pkgs, ...}: {
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    # Sets XCURSOR_* for X11/XWayland clients too, so the cursor doesn't change
    # size when you hover a Proton game.
    x11.enable = true;
  };

  # No `qt` block here on purpose. modules/nixos/desktop.nix already sets
  # qt.platformTheme system-wide, and Caelestia's CLI rewrites the Qt palette
  # from the wallpaper anyway. A second definition in home-manager would just
  # be another QT_QPA_PLATFORMTHEME racing the first.
}
