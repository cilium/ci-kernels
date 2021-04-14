#!/bin/bash

set -eu
set -o pipefail

readonly clang="${CLANG:-clang-12}"
readonly llc="${LLC:=llc-12}"
readonly script_dir="$(cd "$(dirname "$0")"; pwd)"
readonly build_dir="${script_dir}/build"

mkdir -p "${build_dir}"

fetch_and_configure() {
	local kernel_version="$1"
	local src_dir="${build_dir}/linux-${kernel_version}"
	local archive="${build_dir}/linux-${kernel_version}.tar.xz"

	test -e "${archive}" || curl --fail -L "https://cdn.kernel.org/pub/linux/kernel/v${kernel_version%%.*}.x/linux-${kernel_version}.tar.xz" -o "${archive}" 1>&2
	test -d "${src_dir}" || tar --xz -xf "${archive}" -C "${build_dir}" 1>&2

	cd "${src_dir}"
	if [[ ! -f custom.config || "${script_dir}/config" -nt custom.config ]]; then
		echo "Configuring ${kernel_version}" 1>&2
		make KCONFIG_CONFIG=custom.config defconfig 1>&2
		tee -a < "${script_dir}/config" custom.config 1>&2
		make allnoconfig KCONFIG_ALLCONFIG=custom.config 1>&2
		virtme-configkernel --update 1>&2
	fi

	echo "${src_dir}"
}

readonly kernel_versions=("4.9.266" "4.14.230" "4.19.187" "5.4.112" "5.10.30")
for kernel_version in "${kernel_versions[@]}"; do
	series="$(echo "$kernel_version" | cut -d . -f 1-2)"

	if [[ -f "linux-${kernel_version}.bz" ]]; then
		echo "Skipping ${kernel_version}, it already exist"
	else
		cd "$(fetch_and_configure "$kernel_version")"
		make clean
		make -j7 bzImage

		cp "arch/x86/boot/bzImage" "${script_dir}/linux-${kernel_version}.bz"
		if [ "$kernel_version" != "$series" ]; then
			cp -f "${script_dir}/linux-${kernel_version}.bz" "${script_dir}/linux-${series}.bz"
		fi
	fi

	if [[ -f "linux-${kernel_version}-selftests-bpf.bz" ]]; then
		echo "Skipping selftests for ${kernel_version}, they already exist"
		continue
	fi

	if [[ "${series}" = "4.9" ]]; then
		echo "No selftests on 4.9"
		continue
	fi

	cd "$(fetch_and_configure "$kernel_version")"

	if [ "${series}" = "4.14" ]; then
		inc="$(find /usr/include -iregex '.+/asm/bitsperlong\.h$' | head -n 1)"
		export CLANG="$clang '-I${inc%asm/bitsperlong.h}'"
	else
		export CLANG="$clang"
	fi

	export LLC="$llc"

	make -C tools/testing/selftests/bpf -j7
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
	if [ "$kernel_version" != "$series" ]; then
		cp -f "${script_dir}/linux-${kernel_version}-selftests-bpf.bz" "${script_dir}/linux-${series}-selftests-bpf.bz"
	fi
done
