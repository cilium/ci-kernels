#!/bin/bash

set -eux
set -o pipefail

readonly script_dir="$(cd $(dirname "$0"); pwd)"
readonly rootfs_dir="${script_dir}/rootfs"
readonly build_dir="${script_dir}/build"

pushd "${rootfs_dir}"
find . -print0 | cpio --null -o --quiet --format=newc | gzip -9 > "${script_dir}/initramfs.cpio.gz"
zcat "${script_dir}/initramfs.cpio.gz" | cpio -v --list
popd

mkdir -p "${build_dir}"

readonly kernel_versions=("4.19.14")
for kernel_version in "${kernel_versions[@]}"; do
	readonly src_dir="${build_dir}/linux-${kernel_version}"
	readonly archive="${build_dir}/linux-${kernel_version}.tar.xz"

	test -e "${archive}" || curl -L https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${kernel_version}.tar.xz -o "${archive}"
	test -d "${src_dir}" || tar --xz -xf "${archive}" -C "${build_dir}"

	make -C "${src_dir}" KCONFIG_CONFIG=custom.config defconfig
	cat "${script_dir}/config" >> "${src_dir}/custom.config"
	make -C "${src_dir}" allnoconfig KCONFIG_ALLCONFIG="custom.config"

	make -C "${src_dir}" clean
	make -C "${src_dir}" -j$(nproc) bzImage

	mv "${src_dir}/arch/x86/boot/bzImage" "${script_dir}/linux-${kernel_version}"
done


