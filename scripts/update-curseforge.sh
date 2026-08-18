#!/usr/bin/env bash
# CurseForge publishes only a "latest" download URL — there is no versioned
# artefact. So the hash in pkgs/curseforge/default.nix goes stale every time
# they ship a release, and the build fails with a hash mismatch.
#
# That failure is a FEATURE: it means you always know exactly what you're
# installing. This script re-pins to whatever "latest" currently is.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
nixfile="$repo/pkgs/curseforge/default.nix"
url="https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading $url"
curl -fL --progress-bar -o "$tmp/cf.AppImage" "$url"

hash="sha256-$(sha256sum "$tmp/cf.AppImage" | cut -d' ' -f1 | xxd -r -p | base64 -w0)"
echo "==> hash: $hash"

echo "==> reading version from the bundle's own desktop entry"
chmod +x "$tmp/cf.AppImage"
( cd "$tmp" && ./cf.AppImage --appimage-extract '*.desktop' >/dev/null 2>&1 )
version="$(grep -oP '(?<=^X-AppImage-Version=).*' "$tmp"/squashfs-root/*.desktop | head -1 | cut -d- -f1,2)"
echo "==> version: ${version:-<unknown, leaving as-is>}"

sed -i -E "s|(hash = )\"sha256-[^\"]*\";|\1\"$hash\";|" "$nixfile"
[ -n "$version" ] && sed -i -E "s|(version = )\"[^\"]*\";|\1\"$version\";|" "$nixfile"

echo
echo "Updated $nixfile:"
git -C "$repo" diff -- "$nixfile" || true
