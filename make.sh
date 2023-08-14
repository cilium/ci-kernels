#!/bin/bash

set -eu
set -o pipefail

readonly kernel_versions=(
	"6.1.29"
	"5.19.17"
	"5.15.112"
	"5.10.156" # 5.10.157 has broken selftests
	"5.4.243"
	"4.19.283"
	"4.14.320"
	"4.9.337"
)

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
			tar -cvf "${output}" -C "build/${kernel_version}" boot lib
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

	output="linux-${kernel_version}-selftests-bpf.tgz"
	if [[ -f "${output}" ]]; then
		echo "Skipping ${output}, it already exists"
	else
		buildx "${kernel_version}" amd64 selftests "build/${kernel_version}"
		tar -cvf "${output}" --use-compress-program="gzip -9" -C "build/${kernel_version}" tools
		rm -r "build/${kernel_version}"

		if [ "${kernel_version}" != "${series}" ]; then
			cp -f "${output}" "linux-${series}-selftests-bpf.tgz"
		fi
	fi
done
