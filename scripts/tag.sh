#!/usr/bin/env bash

set -eu
set -o pipefail

usage() {
	cat >&2 <<EOF
Tag the current HEAD with a release tag plus floating tags, derived from the
mainline version in matrix/versions.json (rc suffix stripped) and HEAD's
commit timestamp:

  v7.3.202609241435  release, unique per merge, never moves
  v7.3               floating, follows the latest release of that minor
  v7                 floating, follows the latest release of that major

Callers pin the matrix action to a tier of their choice; Dependabot picks up
new releases and major/minor rollovers since the format is version-sortable.

Tags mark caller-observable changes: if matrix/ (including versions.json)
did not change since the last tag, nothing is printed or pushed.

Usage: $0 [--push]

  --push  also create the tags and push them to origin, force-moving the
          floating tags. Without it, tag names are only printed.
EOF
	exit 1
}

push=false
case "${1:-}" in
"") ;;
--push) push=true ;;
*) usage ;;
esac

cd "$(dirname "$0")/.."

# Diffing against the last tag rather than the last push self-heals runs
# where tagging failed or was skipped.
last="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
if [ -n "$last" ] && git diff --quiet "$last" HEAD -- matrix; then
	echo "No changes to matrix/ since $last, nothing to tag." >&2
	exit 0
fi

mainline="$(jq -r '.[] | select(.channel == "mainline") | .version' matrix/versions.json)"
if [ -z "$mainline" ]; then
	echo "Error: no mainline version in matrix/versions.json." >&2
	exit 1
fi

timestamp="$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d%H%M)"
minor="v${mainline%%-*}"
major="v${mainline%%.*}"
release="$minor.$timestamp"

printf '%s\n' "$release" "$minor" "$major"

if [ "$push" = true ]; then
	git tag "$release"
	git tag -f "$minor"
	git tag -f "$major"
	git push origin "refs/tags/$release"
	git push --force origin "refs/tags/$minor" "refs/tags/$major"
fi
