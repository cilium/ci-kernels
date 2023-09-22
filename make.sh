#!/bin/bash

set -eu
set -o pipefail

readonly kernel_versions=(
	# 6.1.39 to 6.1.44: 34fe7aa8ef1d ("libbpf: fix offsetof() and container_of() to work with CO-RE")
	"6.1.38"
	# 5.15.121 to 5.15.125: 71754ee427d7 ("libbpf: fix offsetof() and container_of() to work with CO-RE")
	"5.15.120"
	# 5.10.157 to 50.10.187: f4b8c0710ab6 ("selftests/bpf: Add verifier test for release_reference()")
	# 5.10.188 to 5.10.189: ef7fe1b5c4fb ("libbpf: fix offsetof() and container_of() to work with CO-RE")
	"5.10.156"
	"5.4.252"
	"4.19.290"
	"4.14.321"
	"4.9.337"
)

# release_reference() is fixed by 4237e9f4a962 ("selftests/bpf: Add verifier test for PTR_TO_MEM spill")
# offsetof() is fixed by 416c6d01244e ("selftests/bpf: fix static assert compilation issue for test_cls_*.c")

image="$(<IMAGE)"
version="$(<VERSION)"
readonly image version

verbose() {
	echo "$@"
	"$@"
}

# buildx VERSION ARCH TARGET OUTPUT
buildx() {
	test -e "${4}" && rm -r "${4}"
	verbose docker buildx build -f Dockerfile.binaries --build-arg IMAGE="${image}" --build-arg VERSION="${version}" --build-arg KERNEL_VERSION="${1}" --platform "linux/${2}" --target="${3}" --output="${4}" .
}

for kernel_version in "${kernel_versions[@]}"; do
	series="$(echo "$kernel_version" | cut -d . -f 1-2)"

	for arch in amd64 arm64; do
		output="linux-${kernel_version}-${arch}.tgz"
		if [[ -f "${output}" ]]; then
			echo "Skipping ${output}, it already exists"
		else
			buildx "${kernel_version}" ${arch} vmlinux "build/${kernel_version}"
			tar -cvf "${output}" -C "build/${kernel_version}" .
			rm -r "build/${kernel_version}"

			if [ "${kernel_version}" != "${series}" ]; then
				cp -f "${output}" "linux-${series}-${arch}.tgz"
			fi
		fi
	done

	if [[ "${series}" = "4.4" || "${series}" = "4.9" ]]; then
		echo "No selftests on <= 4.9"
		continue
	fi


	output="linux-${kernel_version}-amd64-selftests-bpf.tgz"
	if [[ -f "${output}" ]]; then
		echo "Skipping ${output}, it already exists"
	else
		buildx "${kernel_version}" amd64 selftests "build/${kernel_version}"
		tar -cvf "${output}" --use-compress-program="gzip -9" -C "build/${kernel_version}" .
		rm -r "build/${kernel_version}"

		if [ "${kernel_version}" != "${series}" ]; then
			cp -f "${output}" "linux-${series}-amd64-selftests-bpf.tgz"
		fi
	fi
done
