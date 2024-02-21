#!/bin/bash
# vmlinux.sh TARGET

set -eu
set -o pipefail

source env.sh

readonly n="${NPROC:-$(nproc)}"

taskset -c "0-$((n - 1))" make -j"$n" vmlinux modules

if [ -d "tools/testing/selftests/bpf/bpf_testmod" ]; then
	make M=tools/testing/selftests/bpf/bpf_testmod modules
fi
