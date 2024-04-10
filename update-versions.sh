#!/bin/bash
# Fetch the releases encoded in the kernel.org homepage and store them as a JSON.

exec curl -sL https://www.kernel.org/releases.json |
	jq '[ .releases[] |
		select(.iseol == false and .moniker != "linux-next") |
		{ "version" : .version, "type" : .moniker }]' |
	tee versions.json
