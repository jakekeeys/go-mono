#!/bin/bash

# Outputs a list of services with changed dependencies.
CHANGED=()

git fetch origin $BRANCH:$BRANCH
for dir in $(grep -l -R "^package main$" --exclude-dir=.git --include="*.go" --exclude="*_test.go" ./services | xargs -n 1 dirname | uniq); do
	app=$(basename $dir)
	if [ -f services/$app/main.go ]; then
		CHANGED+=($(go run .core/cmd/changed/main.go -app=services/$app -base=$BASE -local=$LOCAL_PREFIX -source-revision=origin/$BRANCH -since=0 &>/dev/null && echo $dir | xargs basename))
	else
		CHANGED+=($(go run .core/cmd/changed/main.go -app=services/$app/cmd/$app -base=$BASE -local=$LOCAL_PREFIX -source-revision=origin/$BRANCH -since=0 &>/dev/null && echo $dir | xargs basename))
	fi
done

echo "${CHANGED[@]}" | tr ' ' '\n' | sort -u
