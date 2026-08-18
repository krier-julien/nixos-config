# Matches the current machine exactly: Luxembourg French locale, US keyboard.
{...}: {
  time.timeZone = "Europe/Luxembourg";

  i18n.defaultLocale = "fr_LU.UTF-8";

  # Interface language stays French, but keep LC_MESSAGES-adjacent formatting
  # consistent. Set every LC_* explicitly so a locale change is one edit.
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_LU.UTF-8";
    LC_IDENTIFICATION = "fr_LU.UTF-8";
    LC_MEASUREMENT = "fr_LU.UTF-8";
    LC_MONETARY = "fr_LU.UTF-8";
    LC_NAME = "fr_LU.UTF-8";
    LC_NUMERIC = "fr_LU.UTF-8";
    LC_PAPER = "fr_LU.UTF-8";
    LC_TELEPHONE = "fr_LU.UTF-8";
    LC_TIME = "fr_LU.UTF-8";
  };

  # QWERTY — this is what the machine runs today (VC Keymap: us).
  console.keyMap = "us";
  services.xserver.xkb = {
    layout = "us";
    model = "pc105";
    variant = "";
  };
}
