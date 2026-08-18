{inputs, ...}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];

    # 32 threads on a 7950X3D. max-jobs = how many derivations build at once;
    # cores = how many threads each one gets. 8 × 4 keeps a build from starving
    # the desktop while still using the machine.
    max-jobs = 8;
    cores = 4;

    # Deduplicate the store as it is written. Costs a little build time, saves a
    # lot of disk on a machine that rebuilds often.
    auto-optimise-store = true;

    # Caelestia's flake publishes to its own cache — without these you rebuild
    # quickshell (a large C++/Qt project) from source on every bump.
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    trusted-users = ["root" "julien"];
  };

  # Old generations pile up fast when you rebuild daily. Keep a month.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Pin the system's `nixpkgs` to the exact revision the system was built from,
  # so `nix shell nixpkgs#foo` and `nix-shell -p foo` give you the same package
  # set as the config — not whatever a stale channel happens to hold.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
}
