#!/bin/bash

set -eu
set -o pipefail

readonly clang="${CLANG:-clang-13}"
readonly script_dir="$(cd "$(dirname "$0")"; pwd)"
readonly build_dir="${script_dir}/build"
readonly empty_lsmod="$(mktemp)"

mkdir -p "${build_dir}"

fetch_and_configure() {
	local kernel_version="$1"
	local src_dir="$2"
	local archive="${build_dir}/linux-${kernel_version}.tar.xz"

	test -e "${archive}" || curl --fail -L "https://cdn.kernel.org/pub/linux/kernel/v${kernel_version%%.*}.x/linux-${kernel_version}.tar.xz" -o "${archive}"
	test -d "${src_dir}" || tar --xz -xf "${archive}" -C "${build_dir}"

	cd "${src_dir}"
	if [[ ! -f custom.config || "${script_dir}/config" -nt custom.config ]]; then
		echo "Configuring ${kernel_version}"
		make KCONFIG_CONFIG=custom.config defconfig
		tee -a < "${script_dir}/config" custom.config
		make allnoconfig KCONFIG_ALLCONFIG=custom.config
		virtme-configkernel --update
		make localmodconfig LSMOD="${empty_lsmod}"
	fi
}

readonly kernel_versions=("4.4.131" "4.9.279" "4.14.243" "4.19.202" "5.4.139" "5.10.35")
for kernel_version in "${kernel_versions[@]}"; do
	series="$(echo "$kernel_version" | cut -d . -f 1-2)"
	src_dir="${build_dir}/linux-${kernel_version}"

	if [[ -f "linux-${kernel_version}.bz" ]]; then
		echo "Skipping ${kernel_version}, it already exist"
	else
		fetch_and_configure "$kernel_version" "$src_dir"
		cd "$src_dir"
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

	if [[ "${series}" = "4.4" || "${series}" = "4.9" ]]; then
		echo "No selftests on <= 4.9"
		continue
	fi

	fetch_and_configure "$kernel_version" "$src_dir"
	cd "$src_dir"
	make -j7 modules

	if [ "${series}" = "4.14" ]; then
		inc="$(find /usr/include -iregex '.+/asm/bitsperlong\.h$' | head -n 1)"
		export CLANG="$clang '-I${inc%asm/bitsperlong.h}'"
	else
		export CLANG="$clang"
	fi

	export LLC="llc${clang#clang}"

	make -C tools/testing/selftests/bpf clean
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
