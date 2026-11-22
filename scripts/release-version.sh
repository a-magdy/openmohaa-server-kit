#!/usr/bin/env bash
# Keep the kit version in the reusable server workflows in step with the tag.
#
# Usage:
#   ./scripts/release-version.sh show            print the version the workflows pin
#   ./scripts/release-version.sh check [vX.Y.Z]  all workflows agree (and match the tag)
#   ./scripts/release-version.sh set X.Y.Z       write X.Y.Z into all of them
#
# Each .github/workflows/server-*.yml checks out compose.yaml and deploy/ from
# tag v$KIT_VERSION and runs image tag $KIT_VERSION. If the value in a release
# differed from its tag, callers would get mismatched files and image, so the
# Image workflow runs `check "$GITHUB_REF_NAME"` before publishing and
# pre-commit runs `check` on every change.

set -euo pipefail

die() {
  printf 'release-version: %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS="$SCRIPT_DIR/../.github/workflows"
readonly VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'
readonly LINE_RE='^  KIT_VERSION: "([^"]*)"$'

files() {
  local f found=0
  for f in "$WORKFLOWS"/server-*.yml; do
    [[ -f "$f" ]] || continue
    found=1
    printf '%s\n' "$f"
  done
  ((found)) || die "no .github/workflows/server-*.yml found"
}

# Print "<version> <file>" per workflow; fail if a file has no KIT_VERSION line.
versions() {
  local f line value
  while IFS= read -r f; do
    value=""
    while IFS= read -r line; do
      if [[ "$line" =~ $LINE_RE ]]; then
        value="${BASH_REMATCH[1]}"
        break
      fi
    done <"$f"
    [[ -n "$value" ]] || die "${f##*/}: no '  KIT_VERSION: \"X.Y.Z\"' line under env:"
    printf '%s %s\n' "$value" "${f##*/}"
  done < <(files)
}

single_version() {
  local all
  all="$(versions)"
  if (($(cut -d' ' -f1 <<<"$all" | sort -u | wc -l) != 1)); then
    printf '%s\n' "$all" >&2
    die "the server workflows pin different kit versions; run: $0 set X.Y.Z"
  fi
  cut -d' ' -f1 <<<"$all" | head -n1
}

case "${1:-}" in
  show)
    single_version
    ;;
  check)
    version="$(single_version)"
    [[ "$version" =~ $VERSION_RE ]] || die "KIT_VERSION '$version' must look like 1.2.3"
    if (($# == 2)); then
      tag="$2"
      [[ "$tag" == "v$version" ]] ||
        die "tag $tag does not match KIT_VERSION $version in the server workflows. Run '$0 set ${tag#v}', merge that, and tag the merge commit."
      printf 'Server workflows pin %s, matching tag %s.\n' "$version" "$tag"
    else
      printf 'Server workflows pin %s.\n' "$version"
    fi
    ;;
  set)
    (($# == 2)) || die "usage: $0 set X.Y.Z"
    new="${2#v}"
    [[ "$new" =~ $VERSION_RE ]] || die "version must look like 1.2.3 or 1.2.3-rc.1"
    versions >/dev/null
    while IFS= read -r f; do
      tmp="$(mktemp)"
      sed -E "s/^  KIT_VERSION: \"[^\"]*\"$/  KIT_VERSION: \"$new\"/" "$f" >"$tmp"
      cat "$tmp" >"$f"
      rm -f "$tmp"
    done < <(files)
    printf 'Server workflows now pin %s. Commit, merge, then tag the merge commit v%s.\n' "$new" "$new"
    ;;
  -h | --help)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
    ;;
esac
