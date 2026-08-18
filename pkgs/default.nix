# Packages that are not in nixpkgs. Exposed both as an overlay and as flake
# outputs — see ../flake.nix.
{pkgs}: {
  curseforge = pkgs.callPackage ./curseforge {};
  nxapi = pkgs.callPackage ./nxapi {};
}
