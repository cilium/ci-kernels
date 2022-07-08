#!/bin/bash

set -eu
set -o pipefail

readonly kernel_versions=(
	# "4.4.131" # can't be build on modern toolchains
	"4.9.317"
	"4.14.282"
	"4.19.246"
	"5.4.197"
	"5.10.76" # pinned, selftests don't compile on newer kernels
	"5.15.19"
	"5.18.10" # latest
)

readonly clang="${CLANG:-clang-14}"
readonly clang_suffix="${clang#clang}"
readonly script_dir="$(cd "$(dirname "$0")"; pwd)"
readonly build_dir="${script_dir}/build"
readonly empty_lsmod="$(mktemp)"
readonly n="${NPROC:-$(nproc)}"

mkdir -p "${build_dir}"

fetch_and_configure() {
	local kernel_version="$1"
	local archive="${build_dir}/linux-${kernel_version}.tar.xz"
	local src_dir="${build_dir}/${kernel_version}"

	test -e "${archive}" || curl --fail -L "https://cdn.kernel.org/pub/linux/kernel/v${kernel_version%%.*}.x/linux-${kernel_version}.tar.xz" -o "${archive}"
	if [[ ! -d "${src_dir}" ]]; then
		mkdir "${src_dir}"
		tar --xz -xf "${archive}" -C "${src_dir}" --strip-components=1
	fi

	pushd "${src_dir}"
	if [[ ! -f custom.config || "${script_dir}/config" -nt custom.config ]]; then
		echo "Configuring ${kernel_version}"
		make KCONFIG_CONFIG=custom.config defconfig
		tee -a < "${script_dir}/config" custom.config
		make allnoconfig KCONFIG_ALLCONFIG=custom.config
		virtme-configkernel --update
		make localmodconfig LSMOD="${empty_lsmod}"
	fi
}

fetch_configure_and_clean() {
	fetch_and_configure "$@"
	make clean
	# remove incrementing version numbers on recompilation.
	rm -f .version
}

parallel_make() {
	taskset -c "0-$(($n - 1))" make -j"$n" "$@"
}

export KBUILD_BUILD_TIMESTAMP="$(date --date="@$(<"${script_dir}/VERSION")")"
export KBUILD_BUILD_HOST="ci-kernels-builder"

for kernel_version in "${kernel_versions[@]}"; do
	series="$(echo "$kernel_version" | cut -d . -f 1-2)"

	if [[ -f "${script_dir}/linux-${kernel_version}.bz" ]]; then
		echo "Skipping linux-${kernel_version}.bz, it already exist"
	else
		fetch_configure_and_clean "$kernel_version"
		parallel_make bzImage
		cp "arch/x86/boot/bzImage" "${script_dir}/linux-${kernel_version}.bz"
		popd

		if [ "$kernel_version" != "$series" ]; then
			cp -f "${script_dir}/linux-${kernel_version}.bz" "${script_dir}/linux-${series}.bz"
		fi
	fi

	if [[ -f "${script_dir}/linux-${kernel_version}-selftests-bpf.tgz" ]]; then
		echo "Skipping selftests for ${kernel_version}, they already exist"
		continue
	fi

	if [[ "${series}" = "4.4" || "${series}" = "4.9" ]]; then
		echo "No selftests on <= 4.9"
		continue
	fi

	fetch_and_configure "$kernel_version"
	parallel_make modules

	if [ "${series}" = "4.14" ]; then
		inc="$(find /usr/include -iregex '.+/asm/bitsperlong\.h$' | head -n 1)"
		export CLANG="$clang '-I${inc%asm/bitsperlong.h}'"
	else
		export CLANG="$clang"
	fi

	export LLC="llc${clang_suffix}"
	export LLVM_OBJCOPY="llvm-objcopy${clang_suffix}"
	export LLVM_READELF="llvm-readelf${clang_suffix}"
	export LLVM_STRIP="llvm-strip${clang_suffix}"

	make -C tools/testing/selftests/bpf clean
	parallel_make -C tools/testing/selftests/bpf

	while IFS= read -r obj; do
		if ! readelf -h "$obj" | grep -q "Linux BPF"; then
			continue
		fi

		case "$(basename "$obj")" in
		*.linked[12].o)
			# Intermediate files produced during static linking.
			continue
			;;

		linked_maps[12].o|linked_funcs[12].o|linked_vars[12].o)
			# Inputs to static linking.
			continue
			;;
		esac

		if [ "${series}" = "4.19" ]; then
			# Remove .BTF.ext, since .BTF is rewritten by pahole.
			# See https://lore.kernel.org/bpf/CACAyw9-cinpz=U+8tjV-GMWuth71jrOYLQ05Q7_c34TCeMJxMg@mail.gmail.com/
			"${LLVM_OBJCOPY}" --remove-section .BTF.ext "$obj" 1>&2
		fi
		echo "$obj"
	done < <(find tools/testing/selftests/bpf/. -name . -o -type d -prune -o -type f -name "*.o" -print) | tar cvf "${script_dir}/linux-${kernel_version}-selftests-bpf.tar" -T -

	if [[ -f "tools/testing/selftests/bpf/bpf_testmod/bpf_testmod.ko" ]]; then
		tar rvf "${script_dir}/linux-${kernel_version}-selftests-bpf.tar" "tools/testing/selftests/bpf/bpf_testmod/bpf_testmod.ko"
	fi

	gzip -9 "${script_dir}/linux-${kernel_version}-selftests-bpf.tar"
	mv "${script_dir}/linux-${kernel_version}-selftests-bpf.tar.gz" "${script_dir}/linux-${kernel_version}-selftests-bpf.tgz"
	popd

	if [ "$kernel_version" != "$series" ]; then
		cp -f "${script_dir}/linux-${kernel_version}-selftests-bpf.tgz" "${script_dir}/linux-${series}-selftests-bpf.tgz"
	fi
done
