#!/bin/bash
# copy-debug.sh DEST

set -eux
set -o pipefail

readonly output="${1}"

# Retain vmlinux which includes debug symbols
cp vmlinux "$output/boot/"

# Retain only the sources referenced by dwarf debug info
"${LLVM_DWARFDUMP}" "$output/boot/vmlinux" | \
	awk -f filter-debug.awk | \
	xargs cp -v --no-clobber --parents --target-directory="$output"
