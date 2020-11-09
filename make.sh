#!/bin/bash

set -eu
set -o pipefail

readonly clang="${CLANG:-clang-10}"
readonly script_dir="$(cd "$(dirname "$0")"; pwd)"
readonly build_dir="${script_dir}/build"

mkdir -p "${build_dir}"

readonly kernel_versions=("4.9.241" "4.14.204" "4.19.155" "5.4.75" "5.9.6")
for kernel_version in "${kernel_versions[@]}"; do
	if [[ -f "linux-${kernel_version}.bz" ]]; then
		echo "Skipping ${kernel_version}, it already exist"
		continue
	fi

	src_dir="${build_dir}/linux-${kernel_version}"
	archive="${build_dir}/linux-${kernel_version}.tar.xz"
	series="$(echo "$kernel_version" | cut -d . -f 1-2)"

	test -e "${archive}" || curl --fail -L "https://cdn.kernel.org/pub/linux/kernel/v${kernel_version%%.*}.x/linux-${kernel_version}.tar.xz" -o "${archive}"
	test -d "${src_dir}" || tar --xz -xf "${archive}" -C "${build_dir}"

	pushd "${src_dir}"
	make KCONFIG_CONFIG=custom.config defconfig
	cat "${script_dir}/config" >> "${src_dir}/custom.config"
	make allnoconfig KCONFIG_ALLCONFIG="custom.config"
	virtme-configkernel --update

	make clean
	make -j7 bzImage

	cp "arch/x86/boot/bzImage" "${script_dir}/linux-${kernel_version}.bz"
	cp -f "${script_dir}/linux-${kernel_version}.bz" "${script_dir}/linux-${series}.bz"

	if [ -d "tools/testing/selftests/bpf" ]; then
		if [ "${series}" = "4.14" ]; then
			inc="$(find /usr/include -iregex '.+/asm/bitsperlong\.h$' | head -n 1)"
			export CLANG="$clang '-I${inc%asm/bitsperlong.h}'"
		else
			export CLANG="$clang"
		fi

		make -C tools/testing/selftests/bpf
		while IFS= read -r obj; do
			if readelf -h "$obj" | grep -q "Linux BPF"; then
				if [ "${series}" = "4.19" ]; then
					# Remove .BTF.ext, since .BTF is rewritten by pahole.
					# See https://lore.kernel.org/bpf/CACAyw9-cinpz=U+8tjV-GMWuth71jrOYLQ05Q7_c34TCeMJxMg@mail.gmail.com/
					llvm-objcopy --remove-section .BTF.ext "$obj" 1>&2
				fi
				echo "$obj"
			fi
		done < <(find tools/testing/selftests/bpf -type f -name "*.o") | tar cvjf "${script_dir}/linux-${kernel_version}-selftests-bpf.bz" -T -
		cp -f "${script_dir}/linux-${kernel_version}-selftests-bpf.bz" "${script_dir}/linux-${series}-selftests-bpf.bz"
	fi
	popd
done


