#!/usr/bin/env bash

set -eu
set -o pipefail

usage() {
	cat >&2 <<EOF
Build a kernel using the Dockerfile. Use for development purposes.
This is not invoked on CI, see the corresponding workflow.

Usage: $0 <version> <platform>[,<platform>...] <target> [buildx-args...]

Valid platforms are amd64, arm64.
EOF
	exit 1
}

if [ $# -lt 3 ]; then
	usage
fi

kernel_version="$1"
platform="linux/${2//,/,linux/}"
target="${3}"
shift 3

exec docker buildx build --build-arg KERNEL_VERSION="${kernel_version}" \
	--platform "${platform}" --target="${target}" \
	"$@" "$(dirname "$0")/../build"
