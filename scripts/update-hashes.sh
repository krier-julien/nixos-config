#!/usr/bin/env bash
# Fill in the hashes that Nix can only learn by trying.
#
# There is exactly one of these that MUST be filled before the first build:
# pkgs/nxapi/default.nix's npmDepsHash, which is currently lib.fakeHash. Nix
# cannot know the hash of a dependency set until it has fetched it, so the
# workflow is: build, read the hash out of the failure, write it back.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

fix() {
  local attr="$1" file="$2" field="$3"
  echo "==> $attr"

  # A hash mismatch is the EXPECTED outcome here, so don't let -e kill us.
  local out
  out="$(nix build ".#${attr}" --no-link 2>&1 || true)"

  if ! grep -q 'hash mismatch\|specified:' <<<"$out"; then
    echo "    already correct (or failed for another reason):"
    tail -n 15 <<<"$out" | sed 's/^/    /'
    return 0
  fi

  # Nix prints "specified: sha256-AAAA..." then "got: sha256-real...".
  local got
  got="$(grep -oP '(?<=got:\s{4})sha256-\S+' <<<"$out" | head -1 || true)"
  [ -z "$got" ] && got="$(awk '/got:/{print $2}' <<<"$out" | head -1)"

  if [ -z "$got" ]; then
    echo "    could not parse a hash out of the output:" >&2
    tail -n 30 <<<"$out" | sed 's/^/    /' >&2
    return 1
  fi

  echo "    -> $got"
  sed -i -E "s|($field = )\"?[^\";]*\"?;|\1\"$got\";|" "$file"
}

fix nxapi pkgs/nxapi/default.nix npmDepsHash

echo
echo "Done. Review the diff before committing:"
echo "  git -C '$repo' diff"
