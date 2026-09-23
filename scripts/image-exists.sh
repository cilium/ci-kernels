#!/usr/bin/env bash

set -eu

usage() {
	cat >&2 <<EOF
Check whether an image exists in the registry, without pulling it.

Usage: $0 <ref>

Exits 0 if the manifest exists, 1 otherwise.
EOF
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

docker manifest inspect "$1" > /dev/null 2>&1
