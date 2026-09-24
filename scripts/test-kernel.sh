#!/usr/bin/env bash

set -eu
set -o pipefail

usage() {
	cat >&2 <<EOF
Boot a kernel in a microVM as a smoke test. Accepts either an image
reference or a directory produced by a buildx type=local export, in which
case the current architecture's kernel is selected.

Usage: $0 <image-ref | local-export-dir>
EOF
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

kernel="$1"
if [ -d "$kernel" ]; then
	# Multi-platform local exports place each platform in a subdirectory.
	if [ ! -d "$kernel/boot" ]; then
		kernel="$kernel/linux_$(go env GOARCH)"
	fi
fi

vimto -kernel "$kernel" exec -- /bin/true
echo ok
