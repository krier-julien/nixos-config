# nxapi — Nintendo Switch Online API client. Publishes your Switch activity to
# Discord as Rich Presence. Not in nixpkgs; upstream is
# https://gitlab.fancy.org.uk/samuel/nxapi and it ships to npm.
{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:
buildNpmPackage rec {
  pname = "nxapi";
  version = "1.6.1";

  # The npm tarball, not the git tree. Two reasons:
  #  1. `dist/` is already compiled in it, so there is no rollup/TypeScript
  #     build step and no need for the ~30 devDependencies (which include
  #     Electron — a large, awkward thing to fetch for a CLI you never run the
  #     GUI of).
  #  2. npm tarballs are byte-stable and npm publishes their SRI hash, so the
  #     hash below is exact rather than something you have to discover.
  src = fetchurl {
    url = "https://registry.npmjs.org/nxapi/-/nxapi-${version}.tgz";
    hash = "sha512-fh0S2ztLWIus/M59YUltfhwZcH7yONwSP5mkujVpc3Ika0dKJhTfRuWdPu9OknQXBqDTsaUbIwC4cbrsxiCNcA==";
  };

  nativeBuildInputs = [jq];

  # npm tarballs do not carry a lockfile, and buildNpmPackage requires one. The
  # committed ./package-lock.json was generated from this exact tarball's
  # package.json with devDependencies removed:
  #
  #   npm install --package-lock-only --ignore-scripts
  #
  # 127 packages, all pure JavaScript — nothing here compiles native code.
  # Stripping devDependencies from package.json at build time as well is what
  # makes `npm ci` agree that the lockfile satisfies the manifest.
  postPatch = ''
    jq 'del(.devDependencies, .scripts)' package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./package-lock.json} package-lock.json
  '';

  # ⚠ FILL THIS IN ONCE, ON THE FIRST BUILD.
  # Nix cannot know the hash of the npm dependency set until it has fetched it.
  # Build, let it fail, and paste the "got:" value it prints:
  #
  #   nix build .#nxapi 2>&1 | grep -A2 'got:'
  #
  # Or run ../../scripts/update-hashes.sh, which does exactly that.
  npmDepsHash = lib.fakeHash;

  # dist/ is prebuilt in the tarball and there is no build script to run.
  dontNpmBuild = true;

  meta = {
    description = "Nintendo Switch Online API client with Discord Rich Presence";
    homepage = "https://gitlab.fancy.org.uk/samuel/nxapi";
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "nxapi";
  };
}
