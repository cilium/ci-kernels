#!/bin/bash
# Fetch the releases encoded in the kernel.org homepage and store them as a JSON.

exec curl -sL https://www.kernel.org/ |
xmllint --html --xpath "//table[@id='releases']/tr[.//a[contains(text(), 'tarball')]]/td/strong/text() | //table[@id='releases']/tr[.//a[contains(text(), 'tarball')]]/td[1]/text()" - 2>/dev/null |
awk '
  BEGIN { ORS=""; print "[" }
  /:/ { gsub(/:/, ""); type=$0; getline; version=$0; print (NR>2?",":"") "{\"version\": \"" version "\", \"type\": \"" type "\"}" }
  END { print "]" }
' |
jq '.' | tee versions.json
