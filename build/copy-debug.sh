#!/bin/bash
# copy-debug.sh DEST

set -eux
set -o pipefail

readonly output="${1}"

# Retain vmlinux which includes debug symbols
cp vmlinux "$output/boot/"

# Retain debug scripts
mkdir -p "$output/usr/src/linux"
cp -v vmlinux-gdb.py "$output/usr/src/linux"
ln -s ../usr/src/linux/vmlinux-gdb.py "$output/boot/vmlinux-gdb.py"
find . -path "*/scripts/gdb*" -type f -not -path "*/__pycache__*" -exec cp -v --parents {} "$output/usr/src/linux" \;

# Retain only the sources referenced by dwarf debug info
"${LLVM_DWARFDUMP}" "$output/boot/vmlinux" | \
	awk -f filter-debug.awk | \
	xargs cp -v --no-clobber --parents --target-directory="$output"
