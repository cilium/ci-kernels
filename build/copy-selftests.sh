#!/bin/bash
# copy-selftests.sh DEST

set -eu
set -o pipefail

readonly output="${1}"

# Include only BPF objects, ignoring ones used for producing statically-linked
# objects.
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

	mkdir -p "${output}/$(dirname "$obj")"
	cp -v "$obj" "${output}/$(dirname "$obj")"
done < <(find tools/testing/selftests/bpf/. -name . -o -type d -prune -o -type f -name "*.o" -print)
