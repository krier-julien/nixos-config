# fish + starship — the shell side of the Caelestia setup.
{pkgs, ...}: {
  programs.fish = {
    enable = true;

    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first --git";
      la = "eza -la --icons --group-directories-first --git";
      tree = "eza --tree --icons";
      cat = "bat --style=plain";

      # Rebuild shortcuts. `nom` gives a readable build tree instead of a wall
      # of text; if it isn't installed these still work, just uglier.
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#julien-desktop";
      rebuild-test = "sudo nixos-rebuild test --flake ~/nixos-config#julien-desktop";
      rebuild-boot = "sudo nixos-rebuild boot --flake ~/nixos-config#julien-desktop";
      update = "nix flake update --flake ~/nixos-config";

      # What actually changed between the last two generations.
      whatchanged = "nvd diff /run/current-system /nix/var/nix/profiles/system";
    };

    interactiveShellInit = ''
      set -g fish_greeting
      ${pkgs.zoxide}/bin/zoxide init fish | source
    '';
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$character";
      directory.truncation_length = 3;
      character = {
        success_symbol = "[❯](bold purple)";
        error_symbol = "[❯](bold red)";
      };
      nix_shell.format = "[$symbol$state]($style) ";
    };
  };

  programs.zoxide.enable = true;
  programs.bat.enable = true;

  programs.git = {
    enable = true;
    userName = "krier-julien";
    # GitHub's noreply address. Commits are still attributed to the account and
    # show your avatar, but neither the uni address nor the personal one ends up
    # in a git log — which outlives any decision to make a repo private again.
    userEmail = "krier-julien@users.noreply.github.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  programs.btop = {
    enable = true;
    settings.vim_keys = false;
  };
}
