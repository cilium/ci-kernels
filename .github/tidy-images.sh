#!/bin/bash
# tidy-image.sh org package
# This script removes untagged images from a specified container package within a GitHub organization.

set -euo pipefail

REPOSITORY_OWNER="$1"
PACKAGE_NAME="$2"

ids=$(gh api -X GET "/orgs/${REPOSITORY_OWNER}/packages/container/${PACKAGE_NAME}/versions" -F package_type=container -F per_page=100 -q '.[] | select(.metadata.container.tags | length == 0) | .id')

for id in $ids; do
	echo "Deleting untagged image with ID: $id"
	gh api -X DELETE "/orgs/${REPOSITORY_OWNER}/packages/container/${PACKAGE_NAME}/versions/$id"
done
