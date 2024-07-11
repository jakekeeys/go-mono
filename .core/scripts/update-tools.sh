#!/bin/sh

docker run -it --rm \
	--mount type=bind,source="$PWD",target=/go/src/github.com/jakekeeys/"$(basename $(pwd))" \
	--platform=linux/amd64 \
	-v ~/.ssh:/tmp/.ssh:ro \
	-v ~/.gitconfig:/root/.gitconfig:ro \
	alpine \
	sh -c "./go/src/github.com/jakekeeys/$(basename $(pwd))/.core/scripts/update-tools/update.sh $(basename $(pwd)) $(id -u) $(id -g)"
