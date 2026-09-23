#!/usr/bin/env bash

set -eu
set -o pipefail

usage() {
	cat >&2 <<EOF
Print the candidate image tag for a kernel version: the version followed by
a hash of the build/ directory, which contains all inputs influencing the
image contents. Identical inputs yield an identical tag, allowing CI (and
humans) to skip builds whose output already exists in the registry.

Usage: $0 <kernel-version>
EOF
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

# Hash from the repo root so paths embedded in the output are stable.
cd "$(dirname "$0")/.."

hash="$(find build -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-12)"

echo "$1-$hash"
