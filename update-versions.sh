#!/bin/bash
# Fetch the releases encoded in the kernel.org homepage and store them as a JSON.

read -r -d '' filter <<'EOF'
[ .releases[]
	| select(.iseol == false and .moniker != "linux-next")
	| { "version" : .version, "type" : .moniker, "static_tag": "" }
]
	| group_by(.type)
	| map(.[0].static_tag = .[0].type)
	| flatten
	| map({version, static_tag})
	| sort_by(.version) | reverse
EOF

exec curl -sL https://www.kernel.org/releases.json | jq "$filter" | tee versions.json

