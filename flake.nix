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

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # ---- the machine -----------------------------------------------------
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
            # If a file already exists where home-manager wants to write one, it
            # moves it aside instead of aborting the whole switch.
            backupFileExtension = "hm-bak";
            users.julien = import ./home;
          };
        }
      ];
    };
  };
}
