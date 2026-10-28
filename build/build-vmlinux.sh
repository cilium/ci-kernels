#!/bin/bash
# vmlinux.sh TARGET

set -eu
set -o pipefail

dir="$(dirname "$(realpath "$0")")"

source "$dir/env.sh"

readonly n="${NPROC:-$(nproc)}"

# Don't specify targets explicitly. This saves us from dealing with
# arch-specific names for compressed vmlinux.
taskset -c "0-$((n - 1))" make -j"$n"

if [ -n "$TESTMOD_DIR" ]; then
	make M="$TESTMOD_DIR" modules
fi
