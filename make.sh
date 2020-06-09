#!/bin/bash

set -eu
set -o pipefail

readonly script_dir="$(cd "$(dirname "$0")"; pwd)"
readonly build_dir="${script_dir}/build"

mkdir -p "${build_dir}"

readonly kernel_versions=("4.9.226" "4.14.183" "4.19.127" "5.4.45" "5.7.1")
for kernel_version in "${kernel_versions[@]}"; do
	if [[ -f "linux-${kernel_version}.bz" ]]; then
		echo Skipping ${kernel_version}, it already exist
		continue
	fi

	src_dir="${build_dir}/linux-${kernel_version}"
	archive="${build_dir}/linux-${kernel_version}.tar.xz"
	major_version="$(echo "$kernel_version" | cut -d . -f 1-2)"

	test -e "${archive}" || curl --fail -L https://cdn.kernel.org/pub/linux/kernel/v${kernel_version%%.*}.x/linux-${kernel_version}.tar.xz -o "${archive}"
	test -d "${src_dir}" || tar --xz -xf "${archive}" -C "${build_dir}"

	pushd "${src_dir}"
	make KCONFIG_CONFIG=custom.config defconfig
	cat "${script_dir}/config" >> "${src_dir}/custom.config"
	make allnoconfig KCONFIG_ALLCONFIG="custom.config"
	virtme-configkernel --update

	make clean
	make -j7 bzImage

	mv "arch/x86/boot/bzImage" "${script_dir}/linux-${kernel_version}.bz"
	popd

	pushd "${script_dir}"
	ln -sf "linux-${kernel_version}.bz" "linux-${major_version}.bz"
	popd
done


