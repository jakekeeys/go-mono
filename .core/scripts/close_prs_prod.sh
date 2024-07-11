#!/bin/bash

cd manifests-prod/$MANIFEST_PATH

prs=$(gh pr list --search "[ci]" --state open | grep "to prod" | awk ' { print $1 } ')

for pr in $prs; do
	gh pr close $pr --comment "[ci] Changes are out-of-date and stale - closing." &>/dev/null
done
