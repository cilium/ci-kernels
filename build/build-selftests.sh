#!/bin/bash
# build-selftests.sh

set -eu
set -o pipefail

dir="$(dirname "$(realpath "$0")")"

source "$dir/env.sh"

# Can't figure out how to use cross compilation with selftests.
unset CROSS_COMPILE

make headers
make -C tools/testing/selftests/bpf -j "$(nproc)"
