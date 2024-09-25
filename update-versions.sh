#!/bin/bash
# Fetch the releases encoded in the kernel.org homepage and store them as a JSON.

# Credits: https://stackoverflow.com/a/75770668/1205448
jq_semver_cmp='
  def opt(f):
      . as $in | try f catch $in;
  def semver_cmp:
      sub("\\+.*$"; "")
    | capture("^(?<v>[^-]+)(?:-(?<p>.*))?$") | [.v, .p // empty]
    | map(split(".") | map(opt(tonumber)))
    | .[1] |= (. // {});'

read -r -d '' filter <<'EOF'
[ .releases[]
	| select(.iseol == false and .moniker != "linux-next")
	| { "version" : .version, "type" : .moniker, "static_tag": "" }
]
	| group_by(.type)
	| map(.[0].static_tag = .[0].type)
	| flatten
	| map({version, static_tag})
	| sort_by(.version|semver_cmp) | reverse
EOF

exec curl -sL https://www.kernel.org/releases.json | jq "$jq_semver_cmp""$filter" | tee versions.json

