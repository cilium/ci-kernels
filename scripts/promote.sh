#!/usr/bin/env bash

set -eu
set -o pipefail

usage() {
	cat >&2 <<EOF
Promote candidate images to their public tags via a registry-side manifest
copy. Nothing is pulled or built; the candidate images must already exist.
Requires push access to the registry (docker login ghcr.io).

Usage: $0 <kernel-version> [image-tag]

  kernel-version  version whose candidate images to promote, e.g. 6.12.111
  image-tag       optional floating tag, e.g. longterm. Also promotes the
                  selftests images, which are only built for tagged versions.
                  May be empty, which is the same as omitting it.

Selftests builds break upstream regularly, so missing selftests candidates
are skipped with a warning: the selftests tags keep pointing at the previous
version.

The candidate tag is recomputed from the working tree, so run this from the
commit that produced the candidate images.
EOF
	exit 1
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	usage
fi

version="$1"
image_tag="${2:-}"
readonly IMAGE="ghcr.io/cilium/ci-kernels"

cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain build)" ]; then
	echo "Warning: build/ has uncommitted changes; the candidate tag likely" >&2
	echo "matches no pushed image. Commit or stash first." >&2
fi

candidate="$(scripts/candidate-tag.sh "$version")"

# Mirror docker/metadata-action's pep440 tags: release candidates only get their
# verbatim version, releases also get a (floating) major.minor tag.
tags=("$version")
if [[ "$version" != *-rc* && "$version" == *.*.* ]]; then
	tags+=("${version%.*}")
fi
if [ -n "$image_tag" ]; then
	tags+=("$image_tag")
fi

promote() {
	local suffix="$1"
	shift

	if ! scripts/image-exists.sh "$IMAGE:$candidate$suffix"; then
		echo "Error: $IMAGE:$candidate$suffix does not exist; build and push it first." >&2
		exit 1
	fi

	local args=()
	for tag in "$@"; do
		args+=(-t "$IMAGE:$tag$suffix")
	done

	docker buildx imagetools create "${args[@]}" "$IMAGE:$candidate$suffix"
}

promote "" "${tags[@]}"
promote "-debug" "${tags[@]}"

if [ -n "$image_tag" ]; then
	if scripts/image-exists.sh "$IMAGE:$candidate-selftests"; then
		promote "-selftests" "$image_tag"
		promote "-selftests-debug" "$image_tag"
	else
		echo "Warning: $IMAGE:$candidate-selftests does not exist, skipping selftests promotion." >&2
		echo "$image_tag-selftests still points at the previous version." >&2
	fi
fi
