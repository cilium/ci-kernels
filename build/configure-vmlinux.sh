#!/bin/bash
# configure-vmlinux.sh

set -eu
set -o pipefail

dir="$(dirname "$(realpath "$0")")"

source "$dir/env.sh"

# read_config array file
# read a file in Kconfig format into an associative array.
#
# Valid values are "y", "n", "m". Unset options are turned into "n".
read_config() {
	local -n arr=$1
	local file=$2

	while IFS='=' read -r cfg value
	do
		if [[ -v arr[$cfg] ]]; then
			echo "Error: $cfg is redefined by $file."
			exit 1
		fi

		arr[$cfg]=$value
	done < <(sed -E 's/^# (CONFIG_.+) is not set$/\1=n/; /^\#/d; /^$/d' "$file")
}

# Figure out all valid options
# allconfig doesn't contain all config, since Kconfig seems to omit
# some implicit options like CONFIG_DEBUG_INFO. This is the best I can come
# up with.
declare -A allconfig
make allyesconfig > /dev/null
read_config allconfig .config

# Use defconfig as the base
declare -A config
make defconfig
read_config config .config

# Remove all modules
for cfg in "${!config[@]}"; do
	if [[ "${config[$cfg]}" == "m" ]]; then
		unset config[$cfg]
	fi
done

# Merge configuration snippets
declare -A overrides
for file in "$dir/config" "$dir/config-$ARCH"; do
	echo "Merging $file"
	read_config overrides "$file"
done

for cfg in "${!overrides[@]}"; do
	echo "$cfg=${overrides[$cfg]}"
	config[$cfg]="${overrides[$cfg]}"
done

rm .config
for cfg in "${!config[@]}"; do
	echo "$cfg=${config[$cfg]}" >> .config
done

# Add missing configuration options.
make olddefconfig

# Validate that all the options have the value we want.
declare -A effective
read_config effective .config

status=0
for cfg in "${!overrides[@]}"; do
	if [[ ! -v effective[$cfg] ]]; then
		if [[ ! -v allconfig[$cfg] ]]; then
			echo "Ignoring unrecognised option $cfg"
			continue
		fi

		echo "Option $cfg: not present in config"
		status=1
		continue
	fi

	want="${overrides[$cfg]}"
	have="${effective[$cfg]}"
	case "$want" in
		y|n|m)
			if [[ "$have" != "$want" ]]; then
				echo "Option $cfg: expected '$want', found '$have'"
				status=1
			fi
			;;

		*)
			echo "Option $cfg: don't know how to handle '$want'"
			status=1
			;;
	esac
done

exit $status
