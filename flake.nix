{
  description = "julien's NixOS — Hyprland + Caelestia on a 7950X3D / RTX 4090 desktop";

  inputs = {
    # Unstable, deliberately: Caelestia's own flake follows nixos-unstable, and
    # mixing it with a stable nixpkgs gives you two Qt/wayland versions in one
    # session. Pinning is done by flake.lock, not by the channel.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Caelestia, from AdiAmbassador's animated-wallpaper forks ────────────
    # Not caelestia-dots/shell + caelestia-dots/cli. These two forks add video
    # wallpapers to the shell's own picker — a separate "Animated" category, a
    # QtMultimedia renderer behind the bar, thumbnails, and Material You
    # colours pulled from a frame of the video. That replaced a homegrown
    # mpvpaper service that lived in home/services/wallpaper-video.nix.
    #
    # ⚠ The forks are aimed at Arch and their nix/ directories were inherited
    # from upstream unchanged, so the packaging does NOT know about the new
    # feature. ../home/caelestia.nix patches the two gaps (QtMultimedia for the
    # shell, ffmpeg for the CLI) — read the comment there before bumping either.
    #
    # The shell fork's own flake still points at the UPSTREAM cli, which has
    # none of the video code, so the follows below is what pairs them up.
    caelestia-shell = {
      url = "github:AdiAmbassador/caelestia-shell-aw";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.caelestia-cli.follows = "caelestia-cli";
    };

    caelestia-cli = {
      url = "github:AdiAmbassador/caelestia-cli-aw";
      inputs.nixpkgs.follows = "nixpkgs";
      # Cuts the shell↔cli input cycle; the cli package does not need the shell.
      inputs.caelestia-shell.follows = "";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    system = "x86_64-linux";

    # Plain pkgs (no overlay) — used to expose the custom packages on their own,
    # e.g. `nix build .#curseforge`. Applying the overlay here too would be
    # harmless but makes the recursion harder to reason about.
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    # ---- custom packages -------------------------------------------------
    # Everything under ./pkgs, both as an overlay (so `pkgs.curseforge` works
    # anywhere in the config) and as flake outputs (so you can build one alone).
    overlays.default = final: _prev: import ./pkgs {pkgs = final;};
    packages.${system} = import ./pkgs {inherit pkgs;};

    formatter.${system} = pkgs.alejandra;

    # `nix develop` — the tools you need to work on this repo itself.
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [alejandra nix-output-monitor nvd nix-prefetch];
    };

    # ---- the machine ------------------------------------------------------
    nixosConfigurations.julien-desktop = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules = [
        {
          nixpkgs.overlays = [self.overlays.default];
          nixpkgs.config.allowUnfree = true;
        }

        ./hosts/desktop

        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {inherit inputs;};
            # If a file already exists where home-manager wants to write one,
            # move it aside instead of aborting the whole switch.
            backupFileExtension = "hm-bak";
            users.julien = import ./home;
          };
        }
      ];
    };
  };
}
