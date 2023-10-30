#!/bin/bash

set -eu
set -o pipefail

readonly kernel_versions=(
	"6.6"
	"6.1.55"
	"5.15.132"
	"5.10.197"
	"5.4.257"
	"4.19.295"
	"4.14.326"
	"4.9.337"
)

BUILDER_IMAGE="$(<IMAGE):$(<VERSION)"
export BUILDER_IMAGE

verbose() {
	echo "$@"
	"$@"
}

# buildx KERNEL_VERSION ARCH TARGET ...
buildx() {
	local kernel_version="$1"
	local platform="linux/$2"
	local target="${3}"
	shift 3

	verbose docker buildx build -f Dockerfile.binaries --build-arg BUILDER_IMAGE="${BUILDER_IMAGE}" --build-arg KERNEL_VERSION="${kernel_version}" --platform "${platform}" --target="${target}" "$@" .
}

# derive_output KERNEL_VERSION ARCH TARGET
# Derive the output filename given a couple of variables.
derive_output() {
	local kernel_version="$1"
	local arch="$2"
	local target="$3"

	if [ "$target" == "vmlinux" ]; then
		echo "linux-${kernel_version}-${arch}.tgz"
	else
		echo "linux-${kernel_version}-${arch}-${target}.tgz"
	fi
}

# package KERNEL_VERSION ARCH TARGET
package() {
	local output="$(derive_output "$@")"

	if [[ -f "$output" ]]; then
		echo "Skipping $output, it already exists"
	else
		local tmp="$(mktemp -d)"
		buildx "$1" "$2" "$3" --output="${tmp}"
		tar -cvf "$output" -C "${tmp}" .
		rm -rf "${tmp}"
	fi

	local series="$(echo "$1" | cut -d . -f 1-2)"
	if [ "$1" != "$series" ]; then
		shift 1
		cp -f "$output" "$(derive_output $series "$@")"
	fi
}

for kernel_version in "${kernel_versions[@]}"; do
	series="$(echo "$kernel_version" | cut -d . -f 1-2)"

	for arch in amd64 arm64; do
		package "$kernel_version" $arch vmlinux
	done
done

package "${kernel_versions[0]}" amd64 selftests-bpf
